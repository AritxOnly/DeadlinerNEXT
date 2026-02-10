import { LocalValues } from "../../../common/local/LocalValues";
import { HabitRepository } from "../../../common/repository/HabitRepository";
import { TaskRepository } from "../../../common/repository/TaskRepository";
import { DDLItem, DeadlineType, Habit, HabitGoalType, HabitPeriod, HabitRecordStatus, HabitStatus } from "../../../model/DDLModels";
import { DDLStatus } from "../../../model/DDLStatus";
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { HabitWithDailyStatus } from "../../components/HabitComponents";
import { TaskUIModel } from "../main/TaskListSection";
import { TimelineGroup, TimelineItem, TimelineItemType } from "./TimelineModels";

interface HabitOpt {
  id: number;
  date: Date;
}

@Observed
export class TimelineViewModel {
  groups: TimelineGroup[] = [];
  isLoading: boolean = true;

  todayIndex: number = 0;

  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  constructor() {
    this.refreshData();
  }

  /**
   * 刷新数据核心方法
   */
  async refreshData(): Promise<void> {
    this.isLoading = true;
    const now = new Date();

    // 过去 3 天
    const PAST_DAYS = 3;
    // 未来 14 天 (习惯不能无限生成，需要一个截止日)
    const FUTURE_DAYS = 14;

    const rangeStart = new Date(now);
    rangeStart.setDate(now.getDate() - PAST_DAYS);
    rangeStart.setHours(0, 0, 0, 0);

    const rangeEnd = new Date(now);
    rangeEnd.setDate(now.getDate() + FUTURE_DAYS);
    rangeEnd.setHours(23, 59, 59, 999);

    try {
      const GeneratedDestructArray_1 = await Promise.all([
        this.taskRepo.getDDLsByType(DeadlineType.TASK),
        this.habitRepo.getAllHabits()
      ]);
      const allDDLs = GeneratedDestructArray_1[0];
      const allHabits = GeneratedDestructArray_1[1];

      const timelineItems: TimelineItem[] = [];

      // === 2. 处理 Tasks (DDL) ===
      allDDLs.forEach(task => {
        // 排除已删除和归档
        if (task.isArchived || task.deleted) return;

        const taskTime = new Date(task.endTime).getTime();
        const isCompleted = task.isCompleted;

        if (isCompleted) {
          const sortT = task.completeTime ? new Date(task.completeTime).getTime() : taskTime;
          if (sortT >= rangeStart.getTime() && sortT <= rangeEnd.getTime()) {
            this.pushTaskItem(timelineItems, task, now.getTime());
          }
          return;
        }

        this.pushTaskItem(timelineItems, task, now.getTime());
      });

      const activeHabits = allHabits.filter(h => h.status !== HabitStatus.ARCHIVED);

      const loopDate = new Date(rangeStart);
      const habitPromises: Promise<void>[] = [];

      while (loopDate.getTime() <= rangeEnd.getTime()) {
        const currentDate = new Date(loopDate); // 复制当前日期对象

        for (const habit of activeHabits) {
          if (this.shouldShowHabitOnDate(habit, currentDate)) {
            // 将构建任务放入数组
            habitPromises.push((async () => {
              const status = await this.buildHabitStatus(habit, currentDate);

              // 确定排序时间
              let sortTime = currentDate.getTime();
              if (habit.alarmTime) {
                const parts = habit.alarmTime.split(':').map(Number);
                const d = new Date(currentDate);
                d.setHours(parts[0], parts[1]);
                sortTime = d.getTime();
              } else {
                // 无提醒时间，默认放在当天较晚的时候 (23:59)，排在 Task 后面
                const d = new Date(currentDate);
                d.setHours(23, 59, 59);
                sortTime = d.getTime();
              }

              timelineItems.push({
                // [关键] ID 必须包含日期，否则 List 渲染会 ID 冲突
                id: `habit_${habit.id}_${this.getDateStr(currentDate)}`,
                type: TimelineItemType.HABIT,
                sortTime: sortTime,
                habitData: status
              });
            })());
          }
        }
        // 天数 + 1
        loopDate.setDate(loopDate.getDate() + 1);
      }

      // 等待所有习惯数据计算完成
      await Promise.all(habitPromises);

      // === 4. 分组与排序 ===
      this.groups = this.groupItemsByDate(timelineItems, now, rangeStart);

    } catch (e) {
      console.error('[TimelineVM] Refresh failed:', e);
    } finally {
      this.isLoading = false;
    }
  }

  // 辅助方法：添加 Task Item
  private pushTaskItem(items: TimelineItem[], task: DDLItem, now: number) {
    const uiModel = this.mapToTaskUIModel(task, now);
    items.push({
      id: `task_${task.id}`,
      type: TimelineItemType.TASK,
      sortTime: new Date(task.endTime).getTime(),
      taskData: uiModel
    });
  }

  // === 逻辑块：分组 ===

  private groupItemsByDate(items: TimelineItem[], now: Date, rangeStart: Date): TimelineGroup[] {
    const nowTime = now.getTime();
    const rangeStartTs = rangeStart.getTime();

    // 1. 全局按时间戳排序
    items.sort((a, b) => a.sortTime - b.sortTime);

    // 2. 分组 Map
    const groupMap = new Map<string, TimelineItem[]>();
    const groupOrder: string[] = [];

    // 今天的日期字符串，用于定位
    const todayStr = this.getDateStr(now);

    // 3. 遍历分组
    items.forEach(item => {
      let groupId = '';

      // 判断 Overdue: 只有未完成的 Task，且时间早于 "显示窗口的起点(过去3天)" 才算真正的 Overdue
      // 如果一个任务是昨天到期的，它应该显示在“昨天”那个组里，而不是 Overdue
      const isTaskOverdue = item.type === TimelineItemType.TASK
        && item.taskData?.status !== DDLStatus.COMPLETED
        && item.sortTime < rangeStartTs;

      if (isTaskOverdue) {
        groupId = 'overdue';
      } else {
        // 按日期归类 (YYYY-MM-DD)
        const d = new Date(item.sortTime);
        groupId = this.getDateStr(d);
      }

      if (!groupMap.has(groupId)) {
        groupMap.set(groupId, []);
        // 保持插入顺序即可，因为 item 已经排过序了
        // Overdue 始终置顶
        if (groupId === 'overdue') {
          if (!groupOrder.includes('overdue')) groupOrder.unshift('overdue');
        } else {
          if (!groupOrder.includes(groupId)) groupOrder.push(groupId);
        }
      }
      groupMap.get(groupId)!.push(item);
    });

    // 4. 将 groupOrder 里的非 overdue 部分按日期字符串排序 (确保天数连续)
    const dateGroups = groupOrder.filter(g => g !== 'overdue').sort();
    const finalOrder = groupOrder.includes('overdue') ? ['overdue', ...dateGroups] : dateGroups;

    // 5. 生成结果并寻找今天的位置
    const result = finalOrder.map((gid, index): TimelineGroup => {
      // [关键] 记录今天的索引
      if (gid === todayStr) {
        this.todayIndex = index;
      }

      let title = '';
      if (gid === 'overdue') title = '已过期 / 需要立即处理';
      else {
        title = this.formatDateTitle(new Date(gid));
      }

      return {
        groupId: gid,
        title: title,
        items: groupMap.get(gid)!
      };
    });

    if (!groupMap.has(todayStr)) {
      const foundIndex = finalOrder.findIndex(gid => gid !== 'overdue' && gid >= todayStr);
      if (foundIndex !== -1) this.todayIndex = foundIndex;
      else this.todayIndex = finalOrder.length > 0 ? finalOrder.length - 1 : 0;
    }

    return result;
  }

  private formatDateTitle(date: Date): string {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today); tomorrow.setDate(today.getDate() + 1);
    const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1);
    const beforeYesterday = new Date(today); beforeYesterday.setDate(today.getDate() - 2);

    const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const tTime = target.getTime();

    if (tTime === today.getTime()) return "今天";
    if (tTime === tomorrow.getTime()) return "明天";
    if (tTime === yesterday.getTime()) return "昨天";
    if (tTime === beforeYesterday.getTime()) return "前天";

    const month = target.getMonth() + 1;
    const day = target.getDate();
    const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${month}月${day}日 ${weekDays[target.getDay()]}`;
  }

  private getDateStr(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  private mapToTaskUIModel(item: DDLItem, now: number): TaskUIModel {
    // 简单的日期解析容错
    const parseDate = (str: string): number => {
      const d = new Date(str);
      return isNaN(d.getTime()) ? 0 : d.getTime();
    };

    const start = parseDate(item.startTime);
    const end = parseDate(item.endTime);

    // 1. 计算状态 (Status)
    let status = DDLStatus.UNDERGO;
    if (item.isCompleted) {
      status = DDLStatus.COMPLETED;
    } else if (now > end) {
      status = DDLStatus.PASSED;
    } else if ((end - now) < 24 * 60 * 60 * 1000) {
      status = DDLStatus.NEAR;
    } else {
      status = DDLStatus.UNDERGO;
    }

    // 2. 计算进度 (Progress)
    let progress = 0.0;
    if (item.isCompleted) {
      progress = 1.0;
    } else {
      const totalDuration = end - start;
      const elapsed = now - start;
      if (totalDuration > 0) {
        progress = Math.max(0, Math.min(1, elapsed / totalDuration));
      } else {
        progress = 0;
      }
    }

    const progressDir = LocalValues.getInstance().getProgressDir();
    const displayProgress = progressDir ? progress : 1.0 - progress;

    // 3. 计算剩余时间文本 (TimeText)
    let timeText = "";
    if (item.isCompleted) {
      timeText = "已完成";
    } else {
      const diffMs = end - now;
      if (diffMs < 0) {
        timeText = "已逾期 " + Math.abs(Math.floor(diffMs / (1000 * 60 * 60))) + " 小时";
      } else {
        const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        if (days > 0) {
          timeText = `${days}天 ${hours}小时`;
        } else {
          timeText = `${hours}小时`;
        }
      }
    }

    return {
      dbId: item.id,
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: displayProgress,
      isStarred: item.isStared,
      status: status
    };
  }

  // === 逻辑块：Habit 逻辑 ===
  private shouldShowHabitOnDate(habit: Habit, date: Date): boolean {
    if (habit.period === HabitPeriod.DAILY ||
      habit.period === HabitPeriod.WEEKLY ||
      habit.period === HabitPeriod.MONTHLY) {
      return true;
    }

    const targetDate = new Date(date); targetDate.setHours(0, 0, 0, 0);
    const startDate = new Date(habit.createdAt); startDate.setHours(0, 0, 0, 0);

    if (habit.period === HabitPeriod.ONCE) {
      return targetDate.getTime() === startDate.getTime();
    }

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
      const monday = new Date(d); monday.setDate(diff);
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
  /**
   * 完成任务
   * @param id 任务ID
   * @param onCelebration [新增] 成功完成后的回调（用于触发 Confetti）
   */
  async completeTask(id: number, onCelebration?: () => void): Promise<void> {
    // 1. 震动反馈
    VibrationUtils.vibrateShort();

    try {
      const allDDLs = await this.taskRepo.getAllDDLs();
      const task = allDDLs.find(i => i.id === id);

      if (task) {
        // 状态反转
        const newStatus = !task.isCompleted;
        task.isCompleted = newStatus;

        if (newStatus) {
          task.completeTime = new Date().toISOString();
          // 如果变成了完成状态，执行庆祝回调
          if (onCelebration) {
            onCelebration();
          }
        } else {
          task.completeTime = "";
        }

        await this.taskRepo.updateDDL(task);

        // 刷新列表：完成的任务可能会移动到别的地方或者根据逻辑隐藏/显示
        await this.refreshData();
      }
    } catch (e) {
      console.error('Complete task failed', e);
    }
  }

  /**
   * 删除任务
   * @param id 任务ID
   */
  async deleteTask(id: number): Promise<void> {
    // 1. 震动反馈 (中等强度，表示破坏性操作)
    VibrationUtils.vibrateMedium();

    try {
      await this.taskRepo.deleteDDL(id);
      await this.refreshData();
    } catch (e) {
      console.error('Delete task failed', e);
    }
  }

  /**
   * 切换习惯打卡状态
   * @param habitId 习惯定义的ID (habit.id)
   * @param dateStr 目标日期的时间戳 (Item.sortTime)
   * @param onCelebration 完成时的回调
   */
  async toggleHabit(habitId: number, dateTs: number, onCelebration?: () => void): Promise<void> {
    const targetDate = new Date(dateTs);
    const today = new Date();
    today.setHours(0,0,0,0);

    // 逻辑：不允许对未来日期打卡
    const targetCheck = new Date(targetDate); targetCheck.setHours(0,0,0,0);
    if (targetCheck.getTime() > today.getTime()) {
      return;
    }

    VibrationUtils.vibrateShort();

    try {
      // 1. 获取打卡前的状态（用于判断是否刚刚完成）
      // 这里为了简单，我们假设如果 toggle 成功且当前 done >= target，则触发
      // 更严谨的做法是先查一次，但这里我们相信 refreshData 后的数据

      // 执行打卡
      await this.habitRepo.toggleRecord(habitId, targetDate);

      // 刷新数据
      await this.refreshData();

      // 检查最新状态以触发撒花
      // 我们需要在 groups 里找到刚才那个 item
      // 这步稍微有点耗时，也可以省略，或者在 Repo 层返回最新状态
      // 简单起见：如果 onCelebration 存在，我们假设用户完成了目标（可以优化为只在 0 -> 1 或 99% -> 100% 时触发）
      // 这里暂时不自动触发撒花，交给 UI 根据视觉变化决定，或者这里简单触发一下
      // if (onCelebration) onCelebration();

    } catch (e) {
      console.error('Toggle habit failed', e);
    }
  }

  // --- Batch Operations (Timeline 专用) ---
  // Timeline 同时包含 Task 和 Habit，批量操作需要区分处理

  async batchComplete(selectedIds: string[]): Promise<void> {
    if (selectedIds.length === 0) return;
    VibrationUtils.vibrateShort();

    // ID 格式: "task_123" 或 "habit_456_2023-01-01"
    const taskIds: number[] = [];
    const habitOps: HabitOpt[] = [];

    selectedIds.forEach(fullId => {
      if (fullId.startsWith('task_')) {
        taskIds.push(Number(fullId.split('_')[1]));
      } else if (fullId.startsWith('habit_')) {
        const parts = fullId.split('_'); // habit, id, dateStr
        habitOps.push({ id: Number(parts[1]), date: new Date(parts[2]) });
      }
    });

    try {
      // 1. 完成 Tasks
      if (taskIds.length > 0) {
        const allTasks = await this.taskRepo.getAllDDLs();
        const targets = allTasks.filter(t => taskIds.includes(t.id));
        for (const t of targets) {
          t.isCompleted = true;
          t.completeTime = new Date().toISOString();
          await this.taskRepo.updateDDL(t);
        }
      }

      // 2. 完成 Habits (打卡)
      if (habitOps.length > 0) {
        await Promise.all(habitOps.map(op => {
          return this.habitRepo.insertRecord(op.id, op.date, 1);
        }));
      }

      await this.refreshData();
    } catch (e) { console.error(e) }
  }

  async batchDelete(selectedIds: string[]): Promise<void> {
    if (selectedIds.length === 0) return;
    VibrationUtils.vibrateMedium();

    const taskIds: number[] = [];
    const habitIds: number[] = []; // Habit 删除是删除定义，会影响所有日期

    selectedIds.forEach(fullId => {
      if (fullId.startsWith('task_')) {
        taskIds.push(Number(fullId.split('_')[1]));
      } else if (fullId.startsWith('habit_')) {
        habitIds.push(Number(fullId.split('_')[1]));
      }
    });

    // 去重 Habit ID (因为选了昨天的跑步和今天的跑步，其实删的是同一个习惯)
    const uniqueHabitIds = Array.from(new Set(habitIds));

    try {
      // Task 删除
      for (const id of taskIds) await this.taskRepo.deleteDDL(id);
      // Habit 删除
      for (const id of uniqueHabitIds) await this.habitRepo.deleteHabitByDdlId(id);

      await this.refreshData();
    } catch (e) { console.error(e) }
  }
}