import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants'; // 假设你有对应的 Key
import { SettingsDivider, SettingsSection, SubSettingsSwitch } from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { notificationManager } from '@kit.NotificationKit';

@Builder
export function NotificationSettingsBuilder() {
  NotificationSettings()
}

@Component
struct NotificationSettings {
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 模拟的本地设置 Key，请替换为你实际的 StorageLink
  @State allowNotification: boolean = true;
  @State ddlWarning: boolean = true;
  @State dailySummary: boolean = false;
  @State habitReminder: boolean = true;

  // 检查系统通知权限
  async checkSystemPermission() {
    // 实际开发中，这里应该调用 notificationManager.requestEnableNotification()
    // 并同步 allowNotification 的状态
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {

          // --- 系统权限 ---
          SettingsSection() {
            SubSettingsSwitch({
              title: "允许通知",
              isOn: this.allowNotification,
              onChange: (isOn) => {
                // TODO: 如果关闭，提示用户去系统设置关闭
                // 如果开启，请求系统权限
                this.allowNotification = isOn;
              }
            })
          }

          // --- 细分设置 (只有在允许通知时才可用，或者一直显示) ---
          if (this.allowNotification) {
            SettingsSection({ title: '推送类型' }) {
              SubSettingsSwitch({
                title: "DDL 临近预警",
                subtitle: "智能检测临近截止日期的任务，并提前发送提醒。",
                isOn: this.ddlWarning,
                onChange: (isOn) => {
                  this.ddlWarning = isOn;
                  // LocalValues.getInstance().setDDLWarning(isOn);
                }
              })

              SettingsDivider()

              SubSettingsSwitch({
                title: "每日摘要",
                subtitle: "每天定时推送今日待办任务摘要。",
                isOn: this.dailySummary,
                onChange: (isOn) => {
                  this.dailySummary = isOn;
                }
              })

              SettingsDivider()

              SubSettingsSwitch({
                title: "习惯打卡提醒",
                subtitle: "在您设定的时间提醒您完成习惯打卡。",
                isOn: this.habitReminder,
                onChange: (isOn) => {
                  this.habitReminder = isOn;
                }
              })
            }
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({ content: { title: { mainTitle: "通知与提醒" } } })
  }
}