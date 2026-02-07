import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { SettingsDivider, SettingsSection, SettingsItem, SubSettingsSwitch,
  SubSettingsDivider,
  SettingsCheckItem,
  SettingsSlider} from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';

@Builder
export function InteractionSettingsBuilder() {
  InteractionSettings()
}

interface StartupOption {
  text: string;
  value: number;
}

@Component
struct InteractionSettings {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @Consume('userLocalPathStack') userLocalPathStack: NavPathStack = new NavPathStack();

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  private navigateTo(name: string) {
    if (this.isWideScreen) {
      this.userLocalPathStack.pushPath({ name: name });
    } else {
      this.appPathStack.pushPath({ name: name });
    }
  }

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_VIBRATION_ENABLE) vibrationEnable: boolean = true;
  @StorageLink(C.KEY_FULL_SCREEN_ADD) fullScreenAdd: boolean = false;

  @StorageLink(C.KEY_STARTUP_PAGE) startupPageType: number = 0;
  @StorageLink(C.KEY_SHOW_AI_INPUT) showAiInput: boolean = true;
  @StorageLink(C.KEY_DIRECT_ADD_ON_AI) directAdd: boolean = true;

  @StorageLink(C.KEY_AUTO_ARCHIVE_DAYS) autoArchiveDays: number = 3;

  private options: StartupOption[] = [
    { text: '任务', value: 0 },
    { text: '待办', value: 1 }
  ];

  handleSelect(value: number) {
    this.startupPageType = value;

    console.log(`[Startup] set ${value}`);

    LocalValues.getInstance().setStartupPage(value);
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {

          SettingsSection({ title: '启动页' }) {
            ForEach(this.options, (item: StartupOption, index: number) => {
              SettingsCheckItem({
                title: item.text,
                isSelected: this.startupPageType === item.value,
                onItemClick: () => {
                  this.handleSelect(item.value);
                }
              })

              if (index < this.options.length - 1) {
                SubSettingsDivider()
              }
            })
          }

          // --- 操作体验 ---
          if (!LocalValues.getInstance().getBasicMode()) {
            SettingsSection({ title: '操作体验' }) {
              SubSettingsSwitch({
                title: "触感反馈",
                subtitle: "在完成任务、滑动手势等操作时提供轻微的振动反馈。",
                isOn: this.vibrationEnable,
                onChange: (isOn): Promise<void> => LocalValues.getInstance().setVibration(isOn)
              })

              SubSettingsDivider()

              SubSettingsSwitch({
                title: "全屏添加页面",
                subtitle: "开启后，点击添加按钮将打开沉浸式的全屏页面，而非半屏弹窗。",
                isOn: this.fullScreenAdd,
                onChange: (isOn): Promise<void> => LocalValues.getInstance().setFullScreenAdd(isOn)
              })

              SubSettingsDivider()

              SettingsItem({
                title: "主页快捷功能",
                subtitle: "配置主页顶栏按钮的快捷行为",
                onItemClick: () => {
                  this.navigateTo('settingsMainPageButtons');
                }
              })
            }
          }

          SettingsSection({ title: "AI 交互" }) {
            SubSettingsSwitch({
              title: "添加页面 AI 识别框",
              subtitle: "在添加页面显示 Deadliner AI 任务提取识别框",
              isOn: this.directAdd,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setDirectAddOnAi(isOn)
            })

            SubSettingsDivider()


            SubSettingsSwitch({
              title: "无感任务添加",
              subtitle: "Deadliner AI 对话中点击“去添加”不跳转添加任务页",
              isOn: this.showAiInput,
              onChange: (isOn): Promise<void> => LocalValues.getInstance().setShowAiInput(isOn)
            })
          }

          // --- 自动化 ---
          SettingsSection({ title: '自动化处理' }) {
            // 使用 SettingsSlider 配置天数
            SettingsSlider({
              title: "自动归档期限",
              value: $autoArchiveDays, // 双向绑定
              min: 1,
              max: 30,
              step: 1, // 步长为1，也就是只能选整数天
              valueSuffix: " 天",
              showSteps: false,
              onChange: (value) => {
                // 持久化保存
                LocalValues.getInstance().setAutoArchiveDays(value);
              }
            })
          }

          Text(`已完成的任务将在 ${this.autoArchiveDays} 天后自动移入归档箱，不再显示在主列表中。`)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .padding({ left: 24, right: 24, top: 0, bottom: 24 })
            .lineHeight(16)
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "交互与行为" } }
    })
  }
}