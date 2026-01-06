import { HabitRepository } from "../common/repository/HabitRepository";
import { TaskRepository } from "../common/repository/TaskRepository";
import { DDLItem, DeadlineType, Habit, HabitGoalType, HabitRecordStatus, HabitStatus } from "../model/DDLModels";
import { DDLStatus } from "../model/DDLStatus";
import { HabitWithDailyStatus } from "../pages/components/HabitComponents";

// 定义 UI 需要的数据接口
export interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
  dbId: number;
  originalItem: DDLItem;
}

interface SearchResult {
  tasks: TaskUIModel[];
  habits: HabitWithDailyStatus[];
}

export class SearchUtils {
  private static instance: SearchUtils;
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  private allTasksCache: DDLItem[] = [];
  private allHabitsCache: Habit[] = [];

  public static getInstance(): SearchUtils {
    if (!SearchUtils.instance) {
      SearchUtils.instance = new SearchUtils();
    }
    return SearchUtils.instance;
  }

  /**
   * 预加载所有数据到内存缓存
   */
  async preloadData(): Promise<void> {
    try {
      const tasks = await this.taskRepo.getDDLsByType(DeadlineType.TASK);
      this.allTasksCache = tasks.filter(t => !t.isArchived && !t.deleted);

      const habits = await this.habitRepo.getAllHabits();
      this.allHabitsCache = habits.filter(h => h.status !== HabitStatus.ARCHIVED);
    } catch (e) {
      console.error('[SearchLogic] Preload failed:', e);
    }
  }

  /**
   * 执行搜索
   * @param query 搜索关键词
   * @returns 包含任务和习惯结果的对象
   */
  async executeSearch(query: string): Promise<SearchResult> {
    if (!query || query.trim() === '') {
      return { tasks: [], habits: [] };
    }

    const lowerValue = query.toLowerCase().trim();

    // 1. 任务搜索
    const filteredTasks = this.allTasksCache.filter(item =>
    item.name.toLowerCase().includes(lowerValue) ||
      (item.note && item.note.toLowerCase().includes(lowerValue))
    );
    // 排序：未完成在前
    filteredTasks.sort((a, b) => (Number(a.isCompleted) - Number(b.isCompleted)));
    const taskResults = filteredTasks.map(t => this.mapTaskToUI(t));

    // 2. 习惯搜索
    const filteredHabits = this.allHabitsCache.filter(item =>
    item.name.toLowerCase().includes(lowerValue)
    );

    // 计算习惯状态（默认按今天计算）
    const today = new Date();
    const habitResults = await Promise.all(
      filteredHabits.map(h => this.buildHabitStatusForDate(h, today))
    );

    return { tasks: taskResults, habits: habitResults };
  }

  // --- Helpers ---

  private mapTaskToUI(item: DDLItem): TaskUIModel {
    const now = new Date().getTime();
    const start = item.startTime ? new Date(item.startTime).getTime() : 0;
    const end = item.endTime ? new Date(item.endTime).getTime() : 0;

    let status = DDLStatus.UNDERGO;
    if (item.isCompleted) {
      status = DDLStatus.COMPLETED;
    } else if (now > end) {
      status = DDLStatus.PASSED;
    } else if ((end - now) < 24 * 60 * 60 * 1000) {
      status = DDLStatus.NEAR;
    }

    let progress = 0.0;
    if (item.isCompleted) {
      progress = 1.0;
    } else {
      const totalDuration = end - start;
      const elapsed = now - start;
      if (totalDuration > 0) {
        progress = Math.max(0, Math.min(1, elapsed / totalDuration));
      }
    }

    let timeText = "";
    if (item.isCompleted) {
      timeText = "已完成";
    } else {
      const diffMs = end - now;
      if (diffMs < 0) {
        timeText = "已逾期";
      } else {
        const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        timeText = days > 0 ? `${days}天 ${hours}小时` : `${hours}小时`;
      }
    }

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: progress,
      isStarred: item.isStared,
      status: status,
      dbId: item.id,
      originalItem: item
    };
  }

  private async buildHabitStatusForDate(habit: Habit, date: Date): Promise<HabitWithDailyStatus> {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    let start = d;
    let end = new Date(d); end.setHours(23, 59, 59);

    const queryStart = habit.goalType === HabitGoalType.TOTAL ? new Date(0) : start;
    const records = await this.habitRepo.getRecordsForHabitInRange(habit.id, queryStart, end);

    const done = records
      .filter(r => r.status === HabitRecordStatus.COMPLETED)
      .reduce((sum, r) => sum + r.count, 0);

    let target = Math.max(1, habit.timesPerPeriod);
    if (habit.goalType === HabitGoalType.TOTAL) {
      target = habit.totalTarget ? Math.max(1, habit.totalTarget) : Math.max(1, done);
    }

    return {
      habit: habit,
      doneCount: done,
      targetCount: target,
      isCompleted: habit.totalTarget ? done >= habit.totalTarget : done >= target
    };
  }
}