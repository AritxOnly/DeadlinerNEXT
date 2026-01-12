import { ReminderDataManager } from './ReminderDataManager';
import { ActiveReminder } from '../../model/ActiveReminder';
import { DateTimeUtils } from '../../utils/DateTimeUtils'; // 假设你的工具类在这里
import { DDLItem, Habit, HabitStatus } from '../../model/DDLModels';
import { ReminderUtils } from './ReminderUtils';

// 常量配置
const MAX_DDL_SLOTS = 20;

export class ReminderScheduler {

  static async refreshReminders(allDDLs: DDLItem[]) {
    console.info('[Scheduler] Start refreshing reminders...');
    const manager = ReminderDataManager.getInstance();

    // 1. 获取当前已生效的提醒列表 (账本)
    const activeReminders = manager.getAll().filter(r => r.type === 'DDL');
    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => activeMap.set(r.targetId, r));

    // 2. 数据预处理
    const now = Date.now();

    interface Candidate {
      item: DDLItem;
      date: Date | null;
      timestamp: number;
    }

    const candidates: Candidate[] = allDDLs
      .filter(item => !item.isCompleted && !item.deleted)
      .map((item: DDLItem): Candidate => {
        const date = DateTimeUtils.parseDateString(item.endTime);
        return {
          item: item,
          date: date,
          timestamp: date ? date.getTime() : 0
        };
      })
      // 排除解析失败(null) 或 截止时间已经是过去时间的任务
      // 注意：这里仍然判断截止时间是否在未来，而不是提醒时间
      .filter(c => c.date !== null && c.timestamp > now)
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(0, MAX_DDL_SLOTS);

    const candidateIds = new Set(candidates.map(c => c.item.id.toString()));

    // =========================================================
    // 阶段 A: 清理 (Cancel)
    // =========================================================
    for (const record of activeReminders) {
      // 1. 不在 Top N 名单里
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Out of range / Completed");
        continue;
      }

      // 2. 时间变了 (对比的是 DDL 截止时间)
      const candidate = candidates.find(c => c.item.id.toString() === record.targetId);
      // 这里的 record.triggerTime 存的是截止时间，所以直接对比即可
      if (candidate && Math.abs(candidate.timestamp - record.triggerTime) > 1000) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time changed");
        activeMap.delete(record.targetId);
      }
    }

    // =========================================================
    // 阶段 B: 补录 (Publish)
    // =========================================================
    for (const c of candidates) {
      const idStr = c.item.id.toString();

      if (activeMap.has(idStr)) {
        continue;
      }

      // 修复问题 1：使用 ! 非空断言，因为 filter 已经保证了 date 不为 null
      await ReminderScheduler.publishAndRecord(c.item, c.date!);
    }

    console.info(`[Scheduler] Refresh finished. Active count: ${candidates.length}`);
  }

  /**
   * 刷新习惯打卡提醒
   * @param allHabits 所有习惯列表
   */
  static async refreshHabits(allHabits: Habit[]) {
    console.info('[Scheduler] Start refreshing HABIT reminders...');
    const manager = ReminderDataManager.getInstance();

    // 1. 获取当前已生效的 Habit 提醒
    const activeReminders = manager.getAll().filter(r => r.type === 'HABIT');
    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => activeMap.set(r.targetId, r));

    // 2. 筛选出需要提醒的习惯 (未归档且设置了提醒时间)
    const candidates = allHabits.filter(h =>
    h.status === HabitStatus.ACTIVE &&
    h.alarmTime &&
      h.alarmTime.length > 0
    );

    const candidateIds = new Set(candidates.map(c => c.id.toString()));

    // =========================================================
    // 阶段 A: 清理无效或变更的提醒
    // =========================================================
    for (const record of activeReminders) {
      // 1. 习惯已被删除或不再处于 Active 状态或取消了提醒
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Habit deleted/archived/alarm removed");
        continue;
      }

      // 2. 检查时间是否发生变化
      // 注意：这里我们需要重新计算下一次触发时间来对比
      const habit = candidates.find(c => c.id.toString() === record.targetId);
      if (habit && habit.alarmTime) {
        const nextTime = getNextTriggerTime(habit.alarmTime).getTime();
        // 如果存储的触发时间和计算出的下一次时间差距过大（说明用户修改了时间，或者由于跨天导致需要刷新）
        // 注意：简单的跨天一般不需要取消重建，系统代理会自动处理周期，
        // 但如果 ReminderUtils.publishCalendar 是单次提醒，则每次应用启动都需要检查是否过期并重新发布下一轮。
        // 这里假设我们需要确保 triggerTime 是最新的。

        // 简单策略：如果记录的 triggerTime 已经是过去的时间，或者与新的设置不符(考虑到 HH:mm 变了)，则重建
        const isTimeChanged = Math.abs(record.triggerTime - nextTime) > 1000 && (record.triggerTime % (24*3600*1000) !== nextTime % (24*3600*1000));
        const isExpired = record.triggerTime < Date.now();

        if (isTimeChanged || isExpired) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time changed or expired");
          activeMap.delete(record.targetId); // 允许重新发布
        }
      }
    }

    // =========================================================
    // 阶段 B: 发布新提醒
    // =========================================================
    for (const habit of candidates) {
      const idStr = habit.id.toString();
      if (activeMap.has(idStr)) {
        continue;
      }

      if (habit.alarmTime) {
        await ReminderScheduler.publishHabit(habit);
      }
    }
  }

  /**
   * 刷新每日摘要提醒
   * @param summaryTimeStr 设置的时间字符串 "21:00"，如果为空则视为关闭
   */
  static async refreshDailySummary(summaryTimeStr: string | null) {
    console.info(`[Scheduler] Refreshing Daily Summary: ${summaryTimeStr}`);
    const TARGET_ID = 'DAILY_SUMMARY';
    const manager = ReminderDataManager.getInstance();

    // 查找现有的摘要提醒
    const existingRecord = manager.getByTargetId(TARGET_ID);

    // 情况 1: 用户关闭了摘要提醒 (summaryTimeStr 为 null)
    if (!summaryTimeStr) {
      if (existingRecord) {
        await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Feature disabled");
      }
      return;
    }

    // 计算下一次触发时间
    const nextTriggerDate = getNextTriggerTime(summaryTimeStr);
    const nextTimestamp = nextTriggerDate.getTime();

    // 情况 2: 已存在，判断是否需要更新
    if (existingRecord) {
      // 如果时间没变且未过期，直接返回
      // 允许 1秒内的误差
      if (Math.abs(existingRecord.triggerTime - nextTimestamp) < 1000 && existingRecord.triggerTime > Date.now()) {
        return;
      }
      // 否则先取消旧的
      await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Time update or renew");
    }

    // 情况 3: 发布新的摘要提醒
    try {
      console.info(`[Scheduler] Publishing Daily Summary at ${nextTriggerDate}`);
      const reminderId = await ReminderUtils.publishCalendar(
        "每日摘要",
        "回顾今天，规划明天。点击查看今日概览。",
        nextTriggerDate
      );

      const newRecord: ActiveReminder = {
        targetId: TARGET_ID,
        type: 'SUMMARY', // 确保 ActiveReminder 支持此类型或使用 String
        reminderId: reminderId,
        triggerTime: nextTimestamp
      };
      await manager.addOrUpdate(newRecord);
    } catch (e) {
      console.error(`[Scheduler] Failed to publish daily summary: ${e}`);
    }
  }

  // ==========================================
  // 内部辅助方法
  // ==========================================

  private static async cancelAndRemove(targetId: string, reminderId: number, reason: string) {
    console.info(`[Scheduler] Canceling DDL:${targetId} (ID:${reminderId}). Reason: ${reason}`);
    // 1. 调用 ReminderUtils 取消
    await ReminderUtils.cancel(reminderId);
    // 2. 从本地账本移除
    await ReminderDataManager.getInstance().remove(targetId);
  }

  /**
   * 发布提醒并记录
   * 修改点：此处实现“提前一天提醒”的逻辑
   */
  private static async publishAndRecord(ddl: DDLItem, deadlineDate: Date) {
    console.info(`[Scheduler] Publishing DDL:${ddl.name}...`);
    try {
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      const remindTime = new Date(deadlineDate.getTime() - ONE_DAY_MS);

      const timeStr = formatDeadline(deadlineDate);

      const contentText = ddl.note
        ? `${ddl.note} · 截止于 ${timeStr}`
        : `截止于 ${timeStr}`;

      const reminderId = await ReminderUtils.publishCalendar(
        `任务临近提醒: ${ddl.name}`,
        contentText,
        remindTime
      );

      const newRecord: ActiveReminder = {
        targetId: ddl.id.toString(),
        type: 'DDL',
        reminderId: reminderId,
        triggerTime: deadlineDate.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      console.error(`[Scheduler] Publish failed for ${ddl.name}: ${e}`);
    }
  }

  private static async publishHabit(habit: Habit) {
    if (!habit.alarmTime) return;

    const triggerDate = getNextTriggerTime(habit.alarmTime);
    console.info(`[Scheduler] Publishing Habit:${habit.name} at ${triggerDate}`);

    try {
      const reminderId = await ReminderUtils.publishCalendar(
        `打卡提醒: ${habit.name}`,
        `坚持就是胜利！该完成"${habit.name}"了。`,
        triggerDate
      );

      const newRecord: ActiveReminder = {
        targetId: habit.id.toString(),
        type: 'HABIT',
        reminderId: reminderId,
        triggerTime: triggerDate.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      console.error(`[Scheduler] Publish habit failed: ${e}`);
    }
  }
}

function formatDeadline(date: Date): string {
  const month = date.getMonth() + 1; // 月份从0开始，记得+1
  const day = date.getDate();
  const hour = date.getHours().toString().padStart(2, '0');   // 补零，例如 9 -> 09
  const minute = date.getMinutes().toString().padStart(2, '0');

  return `${month}月${day}日 ${hour}:${minute}`;
}

/**
 * 根据 HH:mm 格式获取下一次触发的时间戳
 * @param timeStr "08:30"
 * @returns Date 对象
 */
function getNextTriggerTime(timeStr: string): Date {
  const now = new Date();
  const timeArray = timeStr.split(':');
  const hourStr = timeArray[0];
  const minuteStr = timeArray[1];
  const hour = parseInt(hourStr);
  const minute = parseInt(minuteStr);

  const target = new Date(now);
  target.setHours(hour, minute, 0, 0);

  // 如果目标时间小于当前时间（即今天的时间点已过），则推迟到明天
  if (target.getTime() <= now.getTime()) {
    target.setDate(target.getDate() + 1);
  }

  return target;
}