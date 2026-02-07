import { HabitRepository } from "../../../common/repository/HabitRepository";
import { TaskRepository } from "../../../common/repository/TaskRepository";
import { DDLItem, DeadlineType, Habit, HabitGoalType, HabitPeriod,
  HabitRecordStatus,
  HabitStatus } from "../../../model/DDLModels";
import { DDLStatus } from "../../../model/DDLStatus";
import { HabitWithDailyStatus } from "../../components/HabitComponents";
import { TaskUIModel } from "../main/TaskListSection";
import { TimelineGroup, TimelineItem, TimelineItemType } from "./TimelineModels";

@Observed
export class TimelineViewModel {
  // UI 绑定的数据源
  groups: TimelineGroup[] = [];
  isLoading: boolean = true;

  // 仓库实例
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  constructor() {
    // 初始化加载
    this.refreshData();
  }

  /**
   * 刷新数据核心方法
   */
  async refreshData(): Promise<void> {
    this.isLoading = true;
    const now = new Date();

    // 设置今天的边界
    const todayStart = new Date(now); todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(now); todayEnd.setHours(23, 59, 59, 999);

    try {
      // 1. 并行获取 Task 和 Habit 数据
      const GeneratedDestructArray_1 = await Promise.all([
        this.taskRepo.getDDLsByType(DeadlineType.TASK),
        this.habitRepo.getAllHabits()
      ]);
      const allDDLs = GeneratedDestructArray_1[0];
      const allHabits = GeneratedDestructArray_1[1];

      const timelineItems: TimelineItem[] = [];

      // 2. 处理 Tasks (DDL)
      // 过滤策略：未归档 && 未删除 && (未完成 OR (已完成且是今天完成的))
      // 这里我们为了时间线简洁，通常只显示未完成的
      const activeTasks = allDDLs.filter(item =>
      !item.isArchived && !item.deleted && !item.isCompleted
      );

      activeTasks.forEach(task => {
        const uiModel = this.mapToTaskUIModel(task, now.getTime());
        timelineItems.push({
          id: `task_${task.id}`,
          type: TimelineItemType.TASK,
          sortTime: new Date(task.endTime).getTime(),
          taskData: uiModel
        });
      });

      // 3. 处理 Habits
      // 策略：只显示“今天”应该出现的习惯
      // 过滤：状态正常 && 符合周期逻辑
      const activeHabits = allHabits.filter(h => h.status !== HabitStatus.ARCHIVED);

      for (const habit of activeHabits) {
        // [关键逻辑] 判断今天是否应该显示该习惯
        if (this.shouldShowHabitOnDate(habit, now)) {
          // 构建状态（已打卡次数等）
          const status = await this.buildHabitStatus(habit, now);

          // 确定排序时间：如果有提醒时间，用提醒时间；否则默认设为今天早上或当前时间
          let sortTime = now.getTime();
          if (habit.alarmTime) {
            const GeneratedDestructArray_1 = habit.alarmTime.split(':').map(Number);
            const h = GeneratedDestructArray_1[0];
            const m = GeneratedDestructArray_1[1];
            const d = new Date(todayStart);
            d.setHours(h, m);
            sortTime = d.getTime();
          } else {
            // 没有提醒时间的习惯，稍微往后放一点，或者置顶，看需求
            // 这里设为今天 23:59 作为一个兜底，让它排在过期任务之后
            sortTime = todayEnd.getTime();
          }

          timelineItems.push({
            id: `habit_${habit.id}`,
            type: TimelineItemType.HABIT,
            sortTime: sortTime,
            habitData: status
          });
        }
      }

      // 4. 分组与排序
      this.groups = this.groupItemsByDate(timelineItems, now);

    } catch (e) {
      console.error('[TimelineVM] Refresh failed:', e);
    } finally {
      this.isLoading = false;
    }
  }

  // === 逻辑块：分组 ===

  private formatDateTitle(date: Date): string {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today); tomorrow.setDate(today.getDate() + 1);

    const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    if (target.getTime() === today.getTime()) {
      return "今天";
    } else if (target.getTime() === tomorrow.getTime()) {
      return "明天";
    } else {
      const month = target.getMonth() + 1;
      const day = target.getDate();
      const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return `${month}月${day}日 ${weekDays[target.getDay()]}`;
    }
  }

  private groupItemsByDate(items: TimelineItem[], now: Date): TimelineGroup[] {
    const nowTime = now.getTime();
    const todayEnd = new Date(now); todayEnd.setHours(23, 59, 59, 999);
    const tomorrowEnd = new Date(now); tomorrowEnd.setDate(tomorrowEnd.getDate() + 1); tomorrowEnd.setHours(23, 59, 59, 999);

    // 全局排序：按 sortTime 升序
    items.sort((a, b) => a.sortTime - b.sortTime);

    // 临时 Map 用来存分组
    // Key: GroupID, Value: Items
    const groupMap = new Map<string, TimelineItem[]>();
    const groupOrder: string[] = ['overdue']; // 保证 overdue 排第一

    items.forEach(item => {
      let groupId = '';

      // 特殊处理：习惯(Habit) 总是归类到 "today"
      // 因为我们上面的逻辑只拉取了"今天"的习惯
      if (item.type === TimelineItemType.HABIT) {
        groupId = this.getDateStr(now); // 今天的日期字符串
      } else {
        // Task 按照时间分布
        if (item.sortTime < nowTime) {
          groupId = 'overdue';
        } else {
          // 将时间戳转为 YYYY-MM-DD 字符串作为 GroupID
          const d = new Date(item.sortTime);
          groupId = this.getDateStr(d);
        }
      }

      if (!groupMap.has(groupId)) {
        groupMap.set(groupId, []);
        if (groupId !== 'overdue') {
          // 如果是新日期，且不在顺序表里，加进去
          // (简单的去重插入，这里数据量小，直接 push 没问题，后面统一 sort)
          if (!groupOrder.includes(groupId)) groupOrder.push(groupId);
        }
      }
      groupMap.get(groupId)!.push(item);
    });

    // 对 groupOrder 中的日期部分（除了 overdue）进行排序
    const dateGroups = groupOrder.filter(g => g !== 'overdue').sort();
    const finalOrder = groupMap.has('overdue') ? ['overdue', ...dateGroups] : dateGroups;

    // 构建结果
    return finalOrder.map((gid): TimelineGroup => {
      let title = '';
      if (gid === 'overdue') title = '已过期 / 需要立即处理';
      else {
        // 解析 YYYY-MM-DD
        const date = new Date(gid);
        title = this.formatDateTitle(date);
      }

      return {
        groupId: gid,
        title: title,
        items: groupMap.get(gid)!
      };
    });
  }

  private getDateStr(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  // === 逻辑块：Task 映射 ===

  private mapToUI(item: DDLItem, now: number): TaskUIModel {
    return this.mapToTaskUIModel(item, now);
  }

  private mapToTaskUIModel(item: DDLItem, now: number): TaskUIModel {
    const start = new Date(item.startTime).getTime();
    const end = new Date(item.endTime).getTime();

    // 1. Status
    let status = DDLStatus.UNDERGO;
    if (item.isCompleted) status = DDLStatus.COMPLETED;
    else if (now > end) status = DDLStatus.PASSED;
    else if ((end - now) < 24 * 60 * 60 * 1000) status = DDLStatus.NEAR;

    // 2. Progress
    let progress = 0.0;
    const totalDuration = end - start;
    const elapsed = now - start;
    if (totalDuration > 0) {
      progress = Math.max(0, Math.min(1, elapsed / totalDuration));
    }

    // 进度条反向逻辑 (复用 LocalValues 里的配置，这里假设默认为 false)
    // const dir = LocalValues.getInstance().getProgressDirection();
    // if (!dir) progress = 1.0 - progress;

    // 3. Time Text
    let timeText = "";
    const diffMs = end - now;
    if (diffMs < 0) {
      timeText = "已逾期 " + Math.abs(Math.floor(diffMs / (1000 * 60 * 60))) + " 小时";
    } else {
      const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      if (days > 0) timeText = `${days}天 ${hours}小时`;
      else timeText = `${hours}小时`;
    }

    return {
      dbId: item.id,
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note,
      progress: progress, // 这里暂时传正向进度，UI如有需要再取反
      isStarred: item.isStared,
      status: status
    };
  }

  // === 逻辑块：Habit 逻辑 (复用自 HabitListSection) ===

  private shouldShowHabitOnDate(habit: Habit, date: Date): boolean {
    // 1. 常规周期
    if (habit.period === HabitPeriod.DAILY ||
      habit.period === HabitPeriod.WEEKLY ||
      habit.period === HabitPeriod.MONTHLY) {
      return true;
    }

    const targetDate = new Date(date); targetDate.setHours(0,0,0,0);
    const startDate = new Date(habit.createdAt); startDate.setHours(0,0,0,0);
    // 如果你有 dedicated startTime 字段: const startDate = new Date(habit.startTime!);

    // 2. 单次
    if (habit.period === HabitPeriod.ONCE) {
      return targetDate.getTime() === startDate.getTime();
    }

    // 3. 艾宾浩斯
    if (habit.period === HabitPeriod.EBBINGHAUS) {
      const diffTime = targetDate.getTime() - startDate.getTime();
      const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
      const curve = [0, 1, 2, 4, 7, 15, 30, 60];
      return curve.includes(diffDays);
    }

    return true;
  }

  private async buildHabitStatus(habit: Habit, date: Date): Promise<HabitWithDailyStatus> {
    const bounds = this.getPeriodBounds(habit.period, date);
    const start = bounds[0];
    const end = bounds[1];

    const queryStart = habit.goalType === HabitGoalType.TOTAL ? new Date(0) : start;
    const queryEnd = habit.goalType === HabitGoalType.TOTAL ? date : end;

    const records = await this.habitRepo.getRecordsForHabitInRange(habit.id, queryStart, queryEnd);
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

  private getPeriodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const d = new Date(date); d.setHours(0, 0, 0, 0);
    if (period === HabitPeriod.DAILY || period === HabitPeriod.ONCE || period === HabitPeriod.EBBINGHAUS) {
      return [d, d];
    } else if (period === HabitPeriod.WEEKLY) {
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      const monday = new Date(d.setDate(diff));
      const sunday = new Date(monday); sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    } else if (period === HabitPeriod.MONTHLY) {
      const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return [firstDay, lastDay];
    }
    return [d, d];
  }

  // === 交互操作 ===

  async completeTask(id: number): Promise<void> {
    try {
      const allDDLs = await this.taskRepo.getAllDDLs();
      const task = allDDLs.find(i => i.id === id);
      if (task) {
        task.isCompleted = true;
        task.completeTime = new Date().toISOString();
        await this.taskRepo.updateDDL(task);
        await this.refreshData(); // 刷新列表，任务会消失（因为只显示未完成）
      }
    } catch (e) {
      console.error('Complete task failed', e);
    }
  }

  async deleteTask(id: number): Promise<void> {
    try {
      await this.taskRepo.deleteDDL(id);
      await this.refreshData();
    } catch (e) {
      console.error('Delete task failed', e);
    }
  }

  async toggleHabit(id: number): Promise<void> {
    try {
      // 对今天的习惯进行打卡
      const now = new Date();
      await this.habitRepo.toggleRecord(id, now);
      await this.refreshData();
    } catch (e) {
      console.error('Toggle habit failed', e);
    }
  }
}