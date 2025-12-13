import { DividerShowType, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@kit.UIDesignKit";
import { LengthMetrics } from "@kit.ArkUI";
import { SettingsDivider, SettingsItem, SettingsSection, SettingsSwitch } from "../../components/SettingsComponents";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { common } from "@kit.AbilityKit";
import { LocalValues } from "../../../common/local/LocalValues";
import { WebParams } from "../../common/WebBrowserPage";
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';

@Component
export struct UserPage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  private context = getContext(this) as common.UIAbilityContext;
  private privacyUrl: string = 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1837914602910842752';

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;

  private showRevokeDialog() {
    AlertDialog.show({
      title: '撤回隐私协议',
      message: '撤回协议后，应用将无法继续为您提供服务，并会自动退出。下次启动应用时，您需要重新同意协议。\n\n确定要撤回吗？',
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {
        },
        fontColor: $r('app.color.brand')
      },
      secondaryButton: {
        value: '确定撤回',
        fontColor: Color.Red,
        action: async () => {
          await LocalValues.getInstance().revokePrivacy();
          this.context.terminateSelf();
        }
      },
      backgroundBlurStyle: BlurStyle.Regular
    })
  }

  build() {
    HdsNavigation() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Scroll() {
          Column({ space: 16 }) {
            SettingsSection() {
              // [新增] 基础模式开关
              SettingsSwitch({
                title: "基础模式",
                subtitle: "仅保留核心任务管理功能",
                icon: $r('sys.symbol.leaf'),
                isOn: this.isBasicMode,
                onChange: (isOn) => {
                  LocalValues.getInstance().setBasicMode(isOn);
                }
              })
            }

            if (!this.isBasicMode) {
              SettingsSection() {
                // WebDAV 设置 (还原你的需求)
                SettingsItem({
                  title: "WebDAV 设置",
                  subtitle: "配置数据同步与备份",
                  icon: $r('sys.symbol.cloud'), // 替换为你想要的图标
                  onItemClick: () => {
                    // 路由跳转
                    this.appPathStack.pushPath({ name: 'settingsWebDav' });
                  }
                })

                SettingsDivider()

                SettingsItem({
                  title: "Deadliner AI",
                  subtitle: "配置 API Key 与模型参数",
                  icon: $r('sys.symbol.AI'),
                  onItemClick: () => {
                    this.appPathStack.pushPath({ name: 'settingsAI' });
                  }
                })
              }
            }

            SettingsSection() {
              SettingsItem({
                title: "撤回隐私协议",
                subtitle: "撤回同意并退出应用",
                icon: $r('sys.symbol.lock_shield'), // [新增] 撤回盾牌图标
                onItemClick: () => {
                  this.showRevokeDialog(); // 触发弹窗
                }
              })
            }

            // 底部留白
            Blank().height(50)
          }
          .width('100%')
          .padding({ bottom: 24, start: LengthMetrics.vp(12), end: LengthMetrics.vp(12) }) // 整体页面的内边距
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .height('100%')
      }
    }
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.COMMON_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(10)
        },
        // --- 初始状态样式 (透明) ---
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
        },
        // --- 滚动生效后样式 (模糊) ---
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_navigation_background_blur'),
          },
        },
      },
      content: {
        // --- 标题内容 ---
        title: {
          mainTitle: '我的'
        },
        divider: { showType: DividerShowType.OFF },
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
  }
}