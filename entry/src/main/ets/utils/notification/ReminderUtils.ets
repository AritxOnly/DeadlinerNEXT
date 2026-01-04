import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class ReminderUtils {

  /**
   * 发布指定时间的提醒 (底层自动转换为 Timer 倒计时)
   * @param title 标题
   * @param content 内容
   * @param targetTime 目标触发时间
   */
  static async publishCalendar(title: string, content: string, targetTime: Date): Promise<number> {
    // 1. 生成唯一的 notificationId
    // 使用 毫秒级时间戳 + 随机数 确保高频点击不冲突
    const reminderId = Math.floor((Date.now() % 1000000) * 100 + Math.random() * 100);

    // 2. 计算时间差 (单位：秒)
    const now = new Date().getTime();
    const target = targetTime.getTime();
    let diffInSeconds = Math.floor((target - now) / 1000);

    // 防御性处理：如果时间是过去的，或者太近（小于1秒），强制设为 1 秒后触发
    if (diffInSeconds < 1) {
      console.warn(`[ReminderUtils] Target time is too close or past. Adjusting to 1s.`);
      diffInSeconds = 1;
    }

    // 3. 使用你那边测试通过的 SOCIAL_COMMUNICATION 类型
    // 既然之前的 Timer 测试证明这个 Slot 是能用的，我们就继续用它
    const mySlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;

    // 4. 构建 Timer 对象 (伪装成 Calendar)
    // 既然 Timer 类型稳定，我们就用 Timer
    let targetReminder: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: diffInSeconds, // 核心：把日期转换为秒数

      title: title,
      content: content,
      // expiredContent: '时间已到', // Timer 也支持这个字段

      actionButton: [
        {
          title: '关闭',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ],

      wantAgent: {
        pkgName: 'com.aritxonly.deadliner', // ⚠️ 再次确认包名正确
        abilityName: 'EntryAbility'
      },

      // 显式指定 ID，方便后续取消
      notificationId: reminderId,

      // 显式指定 Slot，确保通道正确
      slotType: mySlotType,

      // 设为 1 秒，实现“叮”一声即止的普通通知效果
      ringDuration: 0
    };

    try {
      console.info(`[ReminderUtils] Publishing Timer (Virtual Calendar)... Delta: ${diffInSeconds}s, ID: ${reminderId}`);

      // 5. 发布
      const publishedId = await reminderAgentManager.publishReminder(targetReminder);

      console.info(`[ReminderUtils] Success! ID: ${publishedId}`);
      return publishedId;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[ReminderUtils] FAILED: Code=${error.code}, Msg=${error.message}`);
      throw new Error(`Publish error: ${error.code}`);
    }
  }

  static async cancel(reminderId: number) {
    try {
      await reminderAgentManager.cancelReminder(reminderId);
      console.info(`[ReminderUtils] Canceled reminder ID: ${reminderId}`);
    } catch (err) {
      // 忽略取消失败的错误（比如ID不存在）
      console.warn(`[ReminderUtils] Cancel warning: ${JSON.stringify(err)}`);
    }
  }

  static async clearAll() {
    try {
      await reminderAgentManager.cancelAllReminders();
      console.info(`[ReminderUtils] All reminders cleared.`);
    } catch (err) {
      console.error(`[ReminderUtils] Clear all failed: ${JSON.stringify(err)}`);
    }
  }
}