import { HdsNavDestination, HdsNavDestinationAttribute } from "@hms.hds.hdsBaseComponent";
import { notificationManager } from "@kit.NotificationKit";
import { promptAction } from "@kit.ArkUI";
import { reminderAgentManager } from "@kit.BackgroundTasksKit";
import { ReminderUtils } from "../../../utils/notification/ReminderUtils";

@Builder
export function DevOptionsBuilder(name: string, param: Object) {
  DevOptionsPage()
}

const MY_BUNDLE_NAME = "com.aritxonly.deadliner"; // 你的 bundleName
const MY_ABILITY_NAME = "EntryAbility";           // 你的 abilities -> name

@Component
export struct DevOptionsPage {
  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 8 }) {
          Button('📅 发布指定时间提醒 (稳定版)')
            .backgroundColor($r('app.color.chart_green'))
            .width('80%')
            .height(60)
            .onClick(async () => {
              try {
                let targetDate = new Date();
                targetDate.setSeconds(targetDate.getSeconds() + 5); // 5秒后

                let id = await ReminderUtils.publishCalendar(
                  "倒计时模拟日历",
                  "稳如老狗",
                  targetDate
                );
                promptAction.showToast({ message: `发布成功 ID:${id}` });
              } catch (e) {
                promptAction.showToast({ message: `失败: ${(e as Error).message}` });
              }
            })

          Button('🔔 发送普通通知')
            .backgroundColor('#007DFF')
            .width('80%')
            .height(60)
            .onClick(async () => {
              try {
                // 1. 构建通知请求对象
                // 注意：这里严格对应 notificationManager.publish 要求的结构
                let notificationRequest: notificationManager.NotificationRequest = {
                  id: 1001,
                  content: {
                    notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
                    normal: {
                      title: "测试通知",
                      text: "如果你看到这条消息，说明通知参数修正成功了",
                      additionalText: "Test"
                    }
                  },
                  notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
                };

                // 2. 发送
                await notificationManager.publish(notificationRequest);
                console.info('[Notification] publish success');
                promptAction.showToast({ message: '通知发送成功' });

              } catch (err) {
                let error = err as BusinessError;
                console.error(`[Notification] Failed. Code: ${error.code}, Message: ${error.message}`);
                promptAction.showToast({ message: `发送失败: ${error.code}` });
              }
            })

          Button('⏰ 发布倒计时提醒')
            .backgroundColor($r('app.color.accent'))
            .width('80%')
            .height(60)
            .onClick(async () => {
              console.info("Start cancelAllReminders...");

              // 1. 先取消旧的（防止堆积）
              reminderAgentManager.cancelAllReminders((err: BusinessError) => {
                if (err) {
                  console.error("cancelAllReminders failed: " + err.code);
                  // 即使取消失败也继续尝试，万一是没数据导致的失败
                } else {
                  console.info("cancelAllReminders success");
                }

                // 2. 延时 1 秒，等待系统释放配额（关键！）
                setTimeout(async () => {
                  try {
                    let mySlotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;

                    let targetReminder: reminderAgentManager.ReminderRequestTimer = {
                      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
                      triggerTimeInSeconds: 10,
                      title: '倒计时测试',
                      content: '时间到了',
                      actionButton: [
                        {
                          title: '关闭',
                          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
                        }
                      ],
                      wantAgent: {
                        pkgName: 'com.aritxonly.deadliner',
                        abilityName: 'EntryAbility'
                      },
                      notificationId: 1002, // 使用不同的 ID
                      slotType: mySlotType  // 传入断言后的类型
                    };

                    // 3. 发布
                    let reminderId = await reminderAgentManager.publishReminder(targetReminder);
                    console.info('[Reminder] Publish success. ID: ' + reminderId);
                    promptAction.showToast({ message: '提醒发布成功' });

                    // 4. 查库验证
                    const reminders = await reminderAgentManager.getValidReminders();
                    console.info("[Reminder] Valid count in DB: " + reminders.length);

                  } catch (err) {
                    let error = err as BusinessError;
                    console.error(`[Reminder] Failed. Code: ${error.code}, Message: ${error.message}`);

                    if (error.code == 1700002) {
                      promptAction.showToast({ message: '⚠️ 请卸载 App 后重试 (配额死锁)' });
                    } else {
                      promptAction.showToast({ message: `提醒失败: ${error.code}` });
                    }
                  }
                }, 1000); // 延时结束
              });
            })

          // =========================================================
          // 2. 深度状态诊断
          // =========================================================
          Button('🔍 深度状态诊断')
            .backgroundColor('#E65100')
            .width('80%')
            .height(60)
            .onClick(async () => {
              try {
                console.info("============== DIAGNOSIS START ==============");

                const isEnable = await notificationManager.isNotificationEnabled();
                console.info(`[Diagnosis] Global Notification Enabled: ${isEnable}`);

                // 【关键修复】加上 as any
                const slotType = notificationManager.SlotType.SOCIAL_COMMUNICATION;
                const slot = await notificationManager.getSlot(slotType);
                console.info(`[Diagnosis] Slot (SOCIAL) enable: ${slot.enabled}`);
                console.info(`[Diagnosis] Slot (SOCIAL) level: ${slot.level}`);

                try {
                  const reminders = await reminderAgentManager.getValidReminders();
                  console.info(`[Diagnosis] Current Valid Reminders Count: ${reminders.length}`);
                } catch (e) {
                  console.error(`[Diagnosis] getValidReminders crashed: ${JSON.stringify(e)}`);
                }

                console.info("============== DIAGNOSIS END ==============");
                promptAction.showToast({ message: '诊断完成，请看 Log' });

              } catch (err) {
                console.error(`[Diagnosis] Diagnosis script failed: ${JSON.stringify(err)}`);
              }
            })

          Button('🛑 极简核心测试')
            .backgroundColor('#B71C1C')
            .width('80%')
            .height(60)
            .onClick(async () => {
              console.info("Start cancelAllReminders...");

              reminderAgentManager.cancelAllReminders((err: BusinessError) => {
                if (err) {
                  console.error("cancelAllReminders failed code:" + err.code + " message:" + err.message);
                  return;
                }

                console.info("cancelAllReminders callback success. Waiting for quota release...");

                setTimeout(() => {
                  console.info("Delay finished, start publishing...");

                  let timer: reminderAgentManager.ReminderRequestTimer = {
                    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
                    triggerTimeInSeconds: 10
                  }

                  reminderAgentManager.publishReminder(timer, (err: BusinessError, reminderId: number) => {
                    if (err) {
                      console.error("publishReminder failed code:" + err.code + " message:" + err.message);
                    } else {
                      console.info("publishReminder success, reminderId = " + reminderId);
                    }

                    reminderAgentManager.getValidReminders().then((reminders) => {
                      console.info("getValidReminders length = " + reminders.length);
                    });
                  });
                }, 1000);
              });
            })

          Button('✅ 测试 - 官方示例')
            .backgroundColor($r('app.color.accent'))
            .width('80%')
            .height(60)
            .onClick(async () => {
              let targetReminderAgent: reminderAgentManager.ReminderRequestTimer = {
                reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,   // 提醒类型为倒计时类型
                triggerTimeInSeconds: 10,
                actionButton: [ // 设置弹出的提醒通知信息上显示的按钮类型和标题
                  {
                    title: 'close',
                    type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
                  }
                ],
                wantAgent: {     // 点击提醒通知后跳转的目标UIAbility信息
                  pkgName: 'com.aritxonly.deadliner',
                  abilityName: 'EntryAbility'
                },
                title: 'this is title', // 指明提醒标题
                content: 'this is content', // 指明提醒内容
                expiredContent: 'this reminder has expired', // 指明提醒过期后需要显示的内容
                notificationId: 100, // 指明提醒使用的通知的ID号，相同ID号的提醒会覆盖
                ringDuration: -1,
                slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION // 指明提醒的Slot类型
              }

              reminderAgentManager.publishReminder(targetReminderAgent).then((res: number) => {
                console.info('[REMINDER]' + 'Succeeded in publishing reminder. ');
                let reminderId: number = res; // 发布的提醒ID

                console.log('[REMINDER]' + 'REMINDER ID' + reminderId)
              }).catch((err: BusinessError) => {
                console.error(`Failed to publish reminder. Code: ${err.code}, message: ${err.message}`);
              })
            })
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '开发人员模式'
        }
      }
    })
    .backgroundColor($r('app.color.background_primary'))
  }
}