import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 获取当前应用的主 Ability 名字
async function getMainAbilityName(): Promise<string> {
  return "EntryAbility";
}

// 清空所有提醒（解决 1700002 错误）
export async function clearAllReminders() {
  try {
    await reminderAgentManager.cancelAllReminders();
    console.info('[Reminder] ✅ 已清空所有旧提醒，配额已释放');
  } catch (error) {
    console.error(`[Reminder] 清空失败: ${JSON.stringify(error)}`);
  }
}

export async function publishDeadlineReminder(title: string, content: string, targetTime: Date) {

  // 1. 自动获取正确参数
  const myPkgName = (await bundleManager.getBundleInfoForSelf(0)).name;
  const myAbilityName = await getMainAbilityName();

  // 2. 构造时间
  const dateTime: reminderAgentManager.LocalDateTime = {
    year: targetTime.getFullYear(),
    month: targetTime.getMonth() + 1,
    day: targetTime.getDate(),
    hour: targetTime.getHours(),
    minute: targetTime.getMinutes(),
    second: targetTime.getSeconds()
  };

  // 3. 固定一个 ID 用于测试 (避免生成大量垃圾数据占满配额)
  // 实际上线时可以用随机 ID，但测试时我们用固定的，方便“覆盖”旧的
  const TEST_ID = 88888;

  const reminderRequest: reminderAgentManager.ReminderRequestCalendar = {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
    dateTime: dateTime,

    // 核心内容
    title: title,
    content: content,
    notificationId: TEST_ID, // 使用固定 ID，防止爆仓

    // 关键：完全动态获取的跳转目标
    wantAgent: {
      pkgName: myPkgName,
      abilityName: myAbilityName
    },

    snoozeTimes: 0,
    ringDuration: 5,
    // 【关键】移除 slotType，使用系统默认，避免权限问题
  };

  console.info(`[Reminder] 准备发布: Pkg=${myPkgName}, Ability=${myAbilityName}, Time=${JSON.stringify(dateTime)}`);

  try {
    // 4. 先尝试取消这个固定的测试 ID (防止重复)
    try { await reminderAgentManager.cancelReminder(TEST_ID); } catch(e) {}

    // 5. 发布
    const reminderId = await reminderAgentManager.publishReminder(reminderRequest);
    console.info(`[Reminder] 🎉 成功发布! ID: ${reminderId}`);
    return reminderId;
  } catch (error) {
    let err = error as BusinessError;
    // 1700002 = 数量超限; 401 = 参数错误
    console.error(`[Reminder] ❌ 失败. Code: ${err.code}, Msg: ${err.message}`);

    // 如果还是报数量超限，尝试自动清理一次再重试
    if (err.code === 1700002) {
      console.info('[Reminder] 检测到配额满，正在自动清理...');
      await clearAllReminders();
      // 这里可以递归重试一次，或者让用户再点一次按钮
    }
    return -1;
  }
}