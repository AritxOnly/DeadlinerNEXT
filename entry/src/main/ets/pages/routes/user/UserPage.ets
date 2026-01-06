import { DividerShowType, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@kit.UIDesignKit";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { SettingsDivider,
  SettingsGridItem,
  SettingsItem, SettingsSection, SettingsSwitch,
  SettingsUserProfile,
  SettingsVerticalDivider} from "../../components/SettingsComponents";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { common } from "@kit.AbilityKit";
import { LocalValues } from "../../../common/local/LocalValues";
import { WebParams } from "../../common/WebBrowserPage";
import { SettingsConstants as C } from '../../../common/local/SettingsConstants';
import { HuaweiAccountUtils } from "../../../utils/account/HuaweiAccountUtils";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { CodeTextParams } from "../../common/CodeTextPage";
import { ArchivePanelView } from "../../common/ArchivePanelView";
import { AIPanelView } from "../../common/AIPanelView";

@Component
export struct UserPage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  private context = getContext(this) as common.UIAbilityContext;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  @StorageLink(C.KEY_BASIC_MODE) isBasicMode: boolean = false;

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

  @State isArchiveSheetShow: boolean = false;
  @Builder
  archiveSheet() {
    ArchivePanelView()
      .width('100%')
      .height('100%')
  }

  @State isAISheetShow: boolean = false;
  @Builder
  aiSheet() {
    AIPanelView({
      onDismissPanel: () => {
        this.isAISheetShow = false
      }
    })
      .width('100%')
      .height('100%')
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
            Row() {
              SettingsGridItem({
                title: "归档管理",
                icon: $r('sys.symbol.archivebox_fill'),
                iconColor: $r('app.color.brand'),
                onItemClick: () => {
                  this.isArchiveSheetShow = true;
                }
              })

              SettingsVerticalDivider()

              SettingsGridItem({
                title: "AI 助理",
                icon: $r('sys.symbol.wand_and_stars_fill'),
                iconColor: $r('app.color.func_ai'),
                onItemClick: () => {
                  this.isAISheetShow = true;
                }
              })

              SettingsVerticalDivider()

              SettingsGridItem({
                title: "使用手册",
                icon: $r('sys.symbol.book_open_fill'),
                iconColor: $r('app.color.func_manual'),
                onItemClick: () => {
                  this.appPathStack.pushPath({ name: "settingsHelpCenter" })
                }
              })
            }
            .width('100%')
          }

          SettingsSection({ title: '偏好设置' }) {
            SettingsItem({
              title: "显示与个性化",
              subtitle: "界面布局 · 动画效果 · 小组件样式",
              icon: $r('sys.symbol.paintpalette'),
              onItemClick: () => {
                this.appPathStack.pushPath({ name: 'settingsAppearance' });
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "交互与行为",
              subtitle: "触感反馈 · 快捷功能 · 自动归档",
              icon: $r('sys.symbol.hand_point_up_tap'),
              onItemClick: () => {
                this.appPathStack.pushPath({ name: 'settingsInteraction' });
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "通知与提醒",
              subtitle: "DDL 预警 · 每日摘要 · 习惯提醒",
              icon: $r('sys.symbol.bell'),
              onItemClick: () => {
                this.appPathStack.pushPath({ name: 'settingsNotification' });
              }
            })
          }

          if (!this.isBasicMode) {
            SettingsSection({ title: '数据与服务' }) {
              SettingsItem({
                title: "数据同步与备份",
                subtitle: "WebDAV 云同步 · 本地导入导出",
                icon: $r('sys.symbol.cloud'),
                onItemClick: () => {
                  this.appPathStack.pushPath({ name: 'settingsWebDav' });
                }
              })

              SettingsDivider()

              SettingsItem({
                title: "AI 智能服务",
                subtitle: "模型配置 · API Key",
                icon: $r('sys.symbol.AI'),
                onItemClick: () => {
                  this.appPathStack.pushPath({ name: 'settingsAI' });
                }
              })
            }
          }

          SettingsSection({
            title: "隐私协议与许可"
          }) {
            SettingsSwitch({
              title: "基础模式",
              subtitle: "仅保留核心任务管理功能",
              icon: $r('sys.symbol.leaf'),
              isOn: this.isBasicMode,
              onChange: (isOn) => {
                if (isOn) {
                  this.showTurnOnBasicDialog();
                } else {
                  LocalValues.getInstance().setBasicMode(false);
                }
              }
            })

            SettingsDivider()

            SettingsItem({
              title: "开源许可证",
              subtitle: "了解 Deadliner 使用的 MIT 开源协议",
              icon: $r('sys.symbol.doc_text'),
              onItemClick: () => {
                const params: CodeTextParams = {
                  fileName: 'LICENSE.txt',
                  title: '开源许可证'
                };

                this.appPathStack.pushPath({
                  name: 'codeText',
                  param: params
                });
              }
            })

            SettingsDivider()

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

          SettingsSection() {
            SettingsItem({
              title: "开发人员模式",
              subtitle: "Developer Options",
              icon: $r('sys.symbol.code'),
              onItemClick: () => {
                this.appPathStack.pushPath({ name: 'devMode' });
              }
            })
          }

          // 底部留白
          Blank().height(50)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
        .bindSheet($$this.isArchiveSheetShow, this.archiveSheet(), {
          height: SheetSize.FIT_CONTENT,
          dragBar: true,
          onDisappear: () => {
            this.isArchiveSheetShow = false;
          },
          blurStyle: BlurStyle.Regular,
          backgroundColor: Color.Transparent,
          title: {
            title: '归档',
            subtitle: '可以在此处管理你已完成的任务'
          },
        })
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
    .bindSheet($$this.isAISheetShow, this.aiSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      onDisappear: () => {
        this.isAISheetShow = false;
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: 'Deadliner AI',
      }
    })
  }
}