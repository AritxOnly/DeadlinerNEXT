import { DividerShowType, HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@kit.UIDesignKit";
import { LengthMetrics } from "@kit.ArkUI";
import { SettingsDivider, SettingsItem, SettingsSection } from "../../components/SettingsComponents";
import { TopSafeContainer } from "../../components/TopSafeContainer";

@Component
export struct UserPage {
  @Consume('appPathStack') appPathStack: NavPathStack;


  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 56;

  build() {
    HdsNavigation() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT }) {
        Scroll() {
          Column({ space: 16 }) { // Section 之间的间距
            // --- 账户/个人信息区域 (示例) ---
            SettingsSection() {
              SettingsItem({
                title: "My Profile",
                subtitle: "Manage your account info",
                icon: $r('sys.symbol.person_3_fill'),
                onItemClick: () => { /* TODO */
                }
              })
            }

            // --- 核心设置区域 ---
            SettingsSection({ title: "General" }) {
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

              // AI 设置 (示例拓展)
              SettingsItem({
                title: "Deadliner AI",
                subtitle: "配置 API Key 与模型参数",
                icon: $r('sys.symbol.AI'),
                onItemClick: () => { /* TODO */ }
              })
            }

            // --- 关于区域 ---
            SettingsSection({ title: "About" }) {
              SettingsItem({
                title: "Help & Feedback",
                subtitle: "v1.0.0",
                icon: $r('sys.symbol.log'),
                onItemClick: () => {
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
        menu: {
          value: [
            {
              content: {
                label: 'Help',
                icon: $r('sys.symbol.questionmark_circle'),
                action: () => {
                  // TODO: 反馈
                }
              }
            }
          ]
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
  }
}