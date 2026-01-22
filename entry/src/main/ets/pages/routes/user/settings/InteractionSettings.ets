import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { SettingsDivider, SettingsSection, SettingsItem, SubSettingsSwitch,
  SubSettingsDivider,
  SettingsCheckItem} from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';

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

  private options: StartupOption[] = [
    { text: '任务', value: 0 },
    { text: '习惯', value: 1 }
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

          // --- 自动化 ---
          SettingsSection({ title: '自动化处理' }) {
            SettingsItem({
              title: "自动归档规则",
              subtitle: "已完成任务：每天凌晨自动归档", // 这里可以显示当前选中的状态
              onItemClick: () => {
                // TODO: 弹出 ActionSheet 选择：手动、每天、每周
              }
            })
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({ content: { title: { mainTitle: "交互与行为" } } })
  }
}