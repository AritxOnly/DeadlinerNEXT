import { HdsNavDestination, HdsNavDestinationAttribute } from "@hms.hds.hdsBaseComponent";
import { notificationManager } from "@kit.NotificationKit";
import { clearAllReminders, publishDeadlineReminder } from "../../../utils/notification/DeadlinerReminderUtils";
import { promptAction } from "@kit.ArkUI";
import { reminderAgentManager } from "@kit.BackgroundTasksKit";

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
        Column() {
          Button('🛑 极简核心测试')
            .backgroundColor('#B71C1C')
            .width('80%')
            .height(60)
            .onClick(async () => {
              // 1. 清理 (保持这个好习惯)
              try { await reminderAgentManager.cancelAllReminders(); } catch (e) {}

              const target = new Date();
              target.setSeconds(target.getSeconds() + 10);

              const timer: reminderAgentManager.LocalDateTime = {
                year: target.getFullYear(),
                month: target.getMonth() + 1,
                day: target.getDate(),
                hour: target.getHours(),
                minute: target.getMinutes(),
                second: target.getSeconds()
              };

              // 2. 构造“平民版”请求
              const request: reminderAgentManager.ReminderRequestCalendar = {
                reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
                dateTime: timer,

                title: "Deadliner降级测试",
                content: "如果这条能发，说明之前是渠道类型权限不够",

                // 【改动1】删除 notificationId，让系统全权接管
                // notificationId: 10086,

                wantAgent: {
                  pkgName: MY_BUNDLE_NAME,
                  abilityName: MY_ABILITY_NAME
                },

                snoozeTimes: 0,
                ringDuration: 5,
                timeInterval: 0,

                // 【改动2】关键！降级为 OTHER (值是3) 或者 CONTENT_INFORMATION (值是1)
                // 很多非系统App只能用这个
                slotType: notificationManager.SlotType.CONTENT_INFORMATION
              };

              try {
                console.info(`[DEBUG] 正在发布(ContentInfo模式)...`);
                const id = await reminderAgentManager.publishReminder(request);
                console.info(`[DEBUG] 🎉 成功! ID: ${id}`);
                promptAction.showToast({ message: `✅ 成功！ID:${id}\n请锁屏`, duration: 3000 });
              } catch (err) {
                console.error(`[DEBUG] ❌ 失败: Code=${err.code}, Msg=${err.message}`);
                // 打印出完整的 request 以便核对
                console.error(`[DEBUG] Dump: ${JSON.stringify(request)}`);
                promptAction.showToast({ message: `失败: ${err.code}` });
              }
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