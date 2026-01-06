import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { SettingsDivider, SettingsSection, SettingsItem, SubSettingsSwitch } from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { common } from '@kit.AbilityKit';

@Builder
export function AppearanceSettingsBuilder() {
  AppearanceSettings()
}

@Component
struct AppearanceSettings {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 1. 进度条方向
  @StorageLink(C.KEY_PROGRESS_DIRECTION) progressDir: boolean = false;
  // 2. 激励语
  @StorageLink(C.KEY_EXCITEMENT_TEXT) excitementText: boolean = true;
  // 3. 礼花特效
  @StorageLink(C.KEY_CONFETTI_AFTER_FINISHED) confetti: boolean = true;

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {

          // --- 界面布局 ---
          SettingsSection({ title: '界面布局' }) {
            SubSettingsSwitch({
              title: "正向进度条",
              subtitle: "开启后，首页任务卡片将显示“已进行时间”，关闭则显示“剩余时间”。",
              isOn: this.progressDir,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setProgressDir(isOn)
            })

            SettingsDivider()

            SettingsItem({
              title: "小组件样式",
              subtitle: "自定义桌面服务卡片的背景与风格",
              onItemClick: () => {
                this.appPathStack.pushPath({ name: "settingsWidgetBackground" })
              }
            })
          }

          // --- 视觉反馈 ---
          SettingsSection({ title: '视觉反馈' }) {
            SubSettingsSwitch({
              title: "激励语句",
              subtitle: "在首页标题栏显示随机的名言警句，为您的一天注入动力。",
              isOn: this.excitementText,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setExcitementText(isOn)
            })

            SettingsDivider()

            SubSettingsSwitch({
              title: "任务完成礼花",
              subtitle: "当您勾选完成任务时，屏幕上会播放庆祝礼花动画。",
              isOn: this.confetti,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setConfettiAfterFinished(isOn)
            })
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({ content: { title: { mainTitle: "显示与个性化" } } })
  }
}