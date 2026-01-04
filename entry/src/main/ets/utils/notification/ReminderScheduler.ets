import { ReminderDataManager } from './ReminderDataManager';
import { ActiveReminder } from '../../model/ActiveReminder';
import { DateTimeUtils } from '../../utils/DateTimeUtils'; // 假设你的工具类在这里
import { DDLItem } from '../../model/DDLModels';
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
      // 修复问题 2：计算“提前一天”的时间
      // 逻辑：提醒时间 = 截止时间 - 24小时
      const ONE_DAY_MS = 24 * 60 * 60 * 1000;
      const remindTime = new Date(deadlineDate.getTime() - ONE_DAY_MS);

      // 注意：如果 (截止时间 - 1天) 已经是过去的时间了（比如任务明天早上截止，现在是晚上）
      // ReminderUtils (稳定版Timer方案) 会自动将其处理为 "1秒后触发" (即立即提醒)
      // 这符合预期：如果错过了昨天的提醒，现在立刻补发一个。

      // 1. 调用工具类发布 (传入计算后的提醒时间)
      const reminderId = await ReminderUtils.publishCalendar(
        ddl.name,
        // 文案也可以优化一下，提示是提前一天
        `${ddl.note || '任务即将到期'}`,
        remindTime
      );

      // 2. 记账
      const newRecord: ActiveReminder = {
        targetId: ddl.id.toString(),
        type: 'DDL',
        reminderId: reminderId,
        // 关键：这里仍然存 "截止时间"，用于 Diff 比较
        // 如果存提醒时间，下次 diff 会发现时间对不上导致死循环刷新
        triggerTime: deadlineDate.getTime()
      };
      await ReminderDataManager.getInstance().addOrUpdate(newRecord);

    } catch (e) {
      console.error(`[Scheduler] Publish failed for ${ddl.name}: ${e}`);
    }
  }
}