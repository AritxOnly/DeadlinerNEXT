import { DividerShowType, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@kit.UIDesignKit";
import { LengthMetrics } from "@kit.ArkUI";
import { SettingsDivider, SettingsItem, SettingsSection, SettingsSwitch,
  SettingsUserProfile } from "../../components/SettingsComponents";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { common } from "@kit.AbilityKit";
import { LocalValues } from "../../../common/local/LocalValues";
import { WebParams } from "../../common/WebBrowserPage";
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { HuaweiAccountUtils } from "../../../utils/account/HuaweiAccountUtils";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";

@Component
export struct UserPage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  private context = getContext(this) as common.UIAbilityContext;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;
  @StorageLink(C.KEY_VIBRATION_ENABLE) vibrationEnable: boolean = true;
  @StorageLink(C.KEY_PROGRESS_DIRECTION) progressDir: boolean = false;
  @StorageLink(C.KEY_EXCITEMENT_TEXT) excitementText: boolean = true;
  @StorageLink(C.KEY_CONFETTI_AFTER_FINISHED) confetti: boolean = true;
  @StorageLink(C.KEY_FULL_SCREEN_ADD) fullScreenAdd: boolean = false;

  private showRevokeDialog() {
    AlertDialog.show({
      title: '撤回隐私协议',
      message: '撤回协议后，应用将无法继续为您提供服务，并会自动退出账号，清除您的 WebDAV 与 AI API Key 设置。下次启动应用时，您需要重新同意协议。\n\n确定要撤回吗？',
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
          await LocalValues.getInstance().clearAllAdvancedSettings();
          (new HuaweiAccountUtils()).signOut();
          this.context.terminateSelf();
        }
      },
      backgroundBlurStyle: BlurStyle.Regular
    })
  }

  private showTurnOnBasicDialog() {
    AlertDialog.show({
      title: '开启基础模式',
      message: '开启后将清除所有高级设置（AI Key、WebDAV 账号等）并退出当前华为账号。\n\n此操作不可撤销，确定要继续吗？',
      autoCancel: false,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      backgroundBlurStyle: BlurStyle.Regular,
      primaryButton: {
        value: '取消',
        action: () => {
          this.isBasicMode = false;
        },
        fontColor: $r('app.color.brand')
      },
      secondaryButton: {
        value: '确认开启',
        fontColor: Color.Red,
        action: async () => {
          // 1. 清除高级设置
          await LocalValues.getInstance().clearAllAdvancedSettings();

          new HuaweiAccountUtils().signOut();
          AppStorage.setOrCreate('isLoggedIn', false);
          // 3. 设置基础模式为 true
          LocalValues.getInstance().setBasicMode(true);
        }
      }
    });
  }

  private showPrivacyWebPage() {
    const params: WebParams = {
      url: this.privacyUrl,
      title: '隐私协议',
    };

    this.appPathStack.pushPath({
      name: 'webBrowser',
      param: params,
    });
  }

  build() {
    HdsNavigation() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Column({ space: 16 }) {
          if (!this.isBasicMode) {
            SettingsSection() {
              SettingsUserProfile()
            }
          }

          SettingsSection() {
            SettingsSwitch({
              title: "振动反馈",
              subtitle: "开启后，会以振动的形式反馈交互操作",
              icon: $r('sys.symbol.a_4d_vibration'),
              isOn: this.vibrationEnable,
              onChange: (isOn) => {
                LocalValues.getInstance().setVibration(isOn);
              }
            })

            SettingsDivider()

            SettingsSwitch({
              title: "正向进度条",
              subtitle: "主页的任务剩余进度将被替换为任务进行进度",
              icon: $r('sys.symbol.clock_arrow_2_circlepath'),
              isOn: this.progressDir,
              onChange: (isOn) => {
                LocalValues.getInstance().setProgressDir(isOn);
              }
            })

            SettingsDivider()

            SettingsSwitch({
              title: "激励语句",
              subtitle: "在主页标题栏显示随机的激励文案",
              icon: $r('sys.symbol.lightbulb_max'),
              isOn: this.excitementText,
              onChange: (isOn) => {
                LocalValues.getInstance().setExcitementText(isOn);
              }
            })

            SettingsDivider()

            SettingsSwitch({
              title: "礼花动画",
              subtitle: "任务完成时将显示礼花动画效果",
              icon: $r('sys.symbol.flame'),
              isOn: this.confetti,
              onChange: (isOn) => {
                LocalValues.getInstance().setConfettiAfterFinished(isOn);
              }
            })

            SettingsDivider()

            SettingsSwitch({
              title: "全屏添加页面",
              subtitle: "添加任务或习惯时展示全屏界面",
              icon: $r('sys.symbol.full_screen'),
              isOn: this.fullScreenAdd,
              onChange: (isOn) => {
                LocalValues.getInstance().setFullScreenAdd(isOn);
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
            SettingsSwitch({
              title: "基础模式",
              subtitle: "仅保留核心任务管理功能，清除所有高级配置",
              icon: $r('sys.symbol.leaf'),
              isOn: this.isBasicMode,
              onChange: (isOn) => {
                if (isOn) {
                  // 用户试图开启基础模式 -> 弹出警告
                  this.showTurnOnBasicDialog();
                } else {
                  // 用户关闭基础模式 -> 直接执行
                  LocalValues.getInstance().setBasicMode(false);
                }
              }
            })
          }

          SettingsSection() {
            SettingsItem({
              title: "查看隐私协议",
              subtitle: "浏览隐私协议的详细内容",
              icon: $r('sys.symbol.person_shield_fill'),
              onItemClick: () => {
                this.showPrivacyWebPage();
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "撤回隐私协议",
              subtitle: "撤回同意并退出应用",
              icon: $r('sys.symbol.lock_shield'), // [新增] 撤回盾牌图标
              onItemClick: () => {
                this.showRevokeDialog(); // 触发弹窗
              }
            })
          }

          // SettingsSection() {
          //   SettingsItem({
          //     title: "开发人员模式",
          //     subtitle: "Developer Options",
          //     icon: $r('sys.symbol.code'),
          //     onItemClick: () => {
          //       this.appPathStack.pushPath({ name: 'devMode' });
          //     }
          //   })
          // }

          // 底部留白
          Blank().height(50)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
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
        // divider: { showType: DividerShowType.OFF },
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
  }
}