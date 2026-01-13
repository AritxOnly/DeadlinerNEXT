import { ReminderDataManager } from './ReminderDataManager';
import { ActiveReminder } from '../../model/ActiveReminder';
import { DateTimeUtils } from '../../utils/DateTimeUtils';
import { DDLItem, Habit, HabitStatus } from '../../model/DDLModels';
import { ReminderUtils } from './ReminderUtils';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { LocalValues } from '../../common/local/LocalValues';

// 常量配置
const MAX_DDL_SLOTS = 20;

export class ReminderScheduler {

  /**
   * 核心方法：清洗“僵尸”数据
   * * 场景：用户卸载重装（保留数据）或系统清理了过期任务，导致 DB 有记录但系统无任务。
   * 作用：强制对账。如果 DB 里有，但系统里没有，则删除 DB 记录，迫使后续逻辑重新发布。
   */
  private static async syncWithSystem(activeReminders: ActiveReminder[]) {
    if (activeReminders.length === 0) return [];

    try {
      // 1. 获取系统当前所有有效的提醒
      const systemReminders = await reminderAgentManager.getValidReminders();
      // 2. 提取系统中的 ID 集合 (Set 查询效率 O(1))
      const systemIds = new Set(systemReminders.map(r => r.notificationId));

      const manager = ReminderDataManager.getInstance();
      const removedIds: string[] = [];

      // 3. 遍历本地记录进行核对
      for (const record of activeReminders) {
        // 如果本地有 ID，但系统里没有
        if (!systemIds.has(record.reminderId)) {
          console.warn(`[Scheduler] Zombie reminder found! Target:${record.targetId} (ID:${record.reminderId}) is missing in system.`);

          // 从 DB 移除
          await manager.remove(record.targetId);
          removedIds.push(record.targetId);
        }
      }

      return removedIds;
    } catch (e) {
      console.error(`[Scheduler] Sync failed: ${e}. Assuming all local data is valid (safe fallback).`);
      return [];
    }
  }

  // =========================================================
  // 1. DDL 提醒 (单次 - 使用 Timer 伪装)
  // =========================================================
  static async refreshReminders(allDDLs: DDLItem[]) {
    console.info('[Scheduler] Start refreshing DDLs...');

    const isEnabled = LocalValues.getInstance().getDDLWarning();
    const manager = ReminderDataManager.getInstance();

    let activeReminders = manager.getAll().filter(r => r.type === 'DDL');

    await ReminderScheduler.syncWithSystem(activeReminders);

    activeReminders = manager.getAll().filter(r => r.type === 'DDL');

    if (!isEnabled) {
      if (activeReminders.length > 0) {
        console.info('[Scheduler] DDL Warning is DISABLED. Clearing existing reminders...');
        for (const record of activeReminders) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Feature disabled");
        }
      } else {
        console.info('[Scheduler] DDL Warning is DISABLED. No actions needed.');
      }
      return; // ⛔️ 结束流程
    }

    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => activeMap.set(r.targetId, r));

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
      // 过滤掉已过期的任务 (注意：DDL 截止时间必须在未来)
      .filter(c => c.date !== null && c.timestamp > now)
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(0, MAX_DDL_SLOTS);

    const candidateIds = new Set(candidates.map(c => c.item.id.toString()));

    // --- 阶段 A: 清理 (不在 Top N 或时间变更) ---
    for (const record of activeReminders) {
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Out of range / Completed");
        continue;
      }
      const candidate = candidates.find(c => c.item.id.toString() === record.targetId);
      // 如果截止时间变了，需要重新发布
      if (candidate && Math.abs(candidate.timestamp - record.triggerTime) > 1000) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time changed");
        activeMap.delete(record.targetId);
      }
    }

    // --- 阶段 B: 补录 ---
    for (const c of candidates) {
      const idStr = c.item.id.toString();
      // 如果 activeMap 里还有，说明不需要重新发布
      if (activeMap.has(idStr)) continue;

      // 这里直接传截止日期，publishAndRecord 内部会减去1天
      await ReminderScheduler.publishAndRecord(c.item, c.date!);
    }
  }

  // =========================================================
  // 2. 习惯打卡 (循环 - 使用 Alarm)
  // =========================================================
  static async refreshHabits(allHabits: Habit[]) {
    console.info('[Scheduler] Start refreshing HABIT reminders...');

    // 1. 【开关检查】读取配置
    const isEnabled = LocalValues.getInstance().getHabitReminder();
    const manager = ReminderDataManager.getInstance();

    // 2. 获取并清洗数据
    let activeReminders = manager.getAll().filter(r => r.type === 'HABIT');
    await ReminderScheduler.syncWithSystem(activeReminders);
    activeReminders = manager.getAll().filter(r => r.type === 'HABIT');

    const activeMap = new Map<string, ActiveReminder>();
    activeReminders.forEach(r => activeMap.set(r.targetId, r));

    // 3. 【熔断逻辑】如果用户关闭了习惯提醒
    if (!isEnabled) {
      if (activeReminders.length > 0) {
        console.info('[Scheduler] Habit Reminder is DISABLED. Clearing existing reminders...');
        for (const record of activeReminders) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Feature disabled");
        }
      }
      return; // ⛔️ 结束流程
    }

    // 4. 【正常发布逻辑】
    // 筛选有效习惯 (Active 且 设置了 alarmTime)
    const candidates = allHabits.filter(h =>
    h.status === HabitStatus.ACTIVE &&
    h.alarmTime && h.alarmTime.length > 0
    );

    const candidateIds = new Set(candidates.map(c => c.id.toString()));

    // --- 阶段 A: 清理 ---
    for (const record of activeReminders) {
      // 习惯已删除 或 已归档 或 删除了提醒时间
      if (!candidateIds.has(record.targetId)) {
        await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Habit deleted/archived/alarm removed");
        continue;
      }

      // 检查时间 (HH:mm) 是否变化
      const habit = candidates.find(c => c.id.toString() === record.targetId);
      if (habit && habit.alarmTime) {
        const parts = habit.alarmTime.split(':');
        const targetHour = parseInt(parts[0]);
        const targetMinute = parseInt(parts[1]);

        // 获取记录中的时间
        const recordDate = new Date(record.triggerTime);

        // 【关键】只比较 时:分，不比较日期
        if (recordDate.getHours() !== targetHour || recordDate.getMinutes() !== targetMinute) {
          await ReminderScheduler.cancelAndRemove(record.targetId, record.reminderId, "Time(HH:mm) changed");
          activeMap.delete(record.targetId);
        }
      }
    }

    // --- 阶段 B: 发布 ---
    for (const habit of candidates) {
      if (activeMap.has(habit.id.toString())) continue;
      await ReminderScheduler.publishHabit(habit);
    }
  }

  // =========================================================
  // 3. 每日摘要 (循环 - 使用 Alarm)
  // =========================================================
  static async refreshDailySummary(summaryTimeStr: string | null) {
    const TARGET_ID = 'DAILY_SUMMARY';
    const manager = ReminderDataManager.getInstance();
    let existingRecord = manager.getByTargetId(TARGET_ID);

    // 1. 【僵尸数据检测】
    // 在决定是否发布前，先确认现有的 ID 是否真的有效
    if (existingRecord) {
      try {
        const systemReminders = await reminderAgentManager.getValidReminders();
        const existsInSystem = systemReminders.some(r => r.notificationId === existingRecord!.reminderId);

        if (!existsInSystem) {
          console.warn('[Scheduler] Daily Summary zombie record found. Cleaning up...');
          await manager.remove(TARGET_ID); // 只删 DB
          existingRecord = undefined; // 标记为不存在
        }
      } catch (e) {
        console.error('[Scheduler] System check failed for summary.');
      }
    }

    // 2. 【开关检查】
    // 如果 summaryTimeStr 为 null，或者 LocalValues 里关闭了 (双重保障)
    // Settings 页面传参时已经处理了逻辑，传 null 即表示关闭
    if (!summaryTimeStr) {
      if (existingRecord) {
        await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Feature disabled / turned off");
      }
      return;
    }

    // 3. 【正常发布逻辑】
    const parts = summaryTimeStr.split(':');
    const hour = parseInt(parts[0]);
    const minute = parseInt(parts[1]);

    // 检查是否需要更新
    if (existingRecord) {
      const recordDate = new Date(existingRecord.triggerTime);
      // 【关键】只比较 时:分
      if (recordDate.getHours() === hour && recordDate.getMinutes() === minute) {
        console.info('[Scheduler] Daily Summary time unchanged. Skip.');
        return;
      }
      await ReminderScheduler.cancelAndRemove(TARGET_ID, existingRecord.reminderId, "Time update");
    }

    // 发布新提醒
    try {
      const daysOfWeek = [1, 2, 3, 4, 5, 6, 7]; // 每天

      console.info(`[Scheduler] Publishing Daily Summary at ${hour}:${minute}`);

      const reminderId = await ReminderUtils.publishAlarm(
        "每日摘要",
        "回顾今天，规划明天。点击查看今日概览。",
        hour,
        minute,
        daysOfWeek
      );

      const recordTime = new Date();
      recordTime.setHours(hour, minute, 0, 0);

      const newRecord: ActiveReminder = {
        targetId: TARGET_ID,
        type: 'SUMMARY',
        reminderId: reminderId,
        triggerTime: recordTime.getTime()
      };
      await manager.addOrUpdate(newRecord);
    } catch (e) {
      console.error(`[Scheduler] Failed to publish summary: ${e}`);
    }
  }

  // ==========================================
  // 内部辅助
  // ==========================================

  private static async cancelAndRemove(targetId: string, reminderId: number, reason: string) {
    console.info(`[Scheduler] Canceling ${targetId} (ID:${reminderId}). Reason: ${reason}`);
    await ReminderUtils.cancel(reminderId);
    await ReminderDataManager.getInstance().remove(targetId);
  }

  private static async publishAndRecord(ddl: DDLItem, deadlineDate: Date) {
    try {
      // 提前一天提醒
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      const remindTime = new Date(deadlineDate.getTime() - ONE_DAY_MS);
      const timeStr = formatDeadline(deadlineDate);

      const contentText = ddl.note ? `${ddl.note} · 截止于 ${timeStr}` : `截止于 ${timeStr}`;

      // 【调用 Timer 伪装的 Calendar 接口】
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
      console.error(`[Scheduler] Publish DDL failed: ${e}`);
    }
  }

  private static async publishHabit(habit: Habit) {
    if (!habit.alarmTime) return;
    try {
      const parts = habit.alarmTime.split(':');
      const hour = parseInt(parts[0]);
      const minute = parseInt(parts[1]);
      const daysOfWeek = [1, 2, 3, 4, 5, 6, 7];

      console.info(`[Scheduler] Publishing Habit:${habit.name} at ${hour}:${minute}`);

      // 【调用 Alarm 接口】
      const reminderId = await ReminderUtils.publishAlarm(
        `打卡提醒: ${habit.name}`,
        `坚持就是胜利！该完成"${habit.name}"了。`,
        hour,
        minute,
        daysOfWeek
      );

      const recordTime = new Date();
      recordTime.setHours(hour, minute, 0, 0);

      const newRecord: ActiveReminder = {
        targetId: habit.id.toString(),
        type: 'HABIT',
        reminderId: reminderId,
        triggerTime: recordTime.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      console.error(`[Scheduler] Publish habit failed: ${e}`);
    }
  }
}

function formatDeadline(date: Date): string {
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const hour = date.getHours().toString().padStart(2, '0');
  const minute = date.getMinutes().toString().padStart(2, '0');
  return `${month}月${day}日 ${hour}:${minute}`;
}