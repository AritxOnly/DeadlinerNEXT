import { HdsNavigation, HdsNavigationAttribute, } from '@hms.hds.hdsBaseComponent';
import { LengthMetrics, promptAction, SymbolGlyphModifier } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { PrivacyDialog } from './components/PrivacyDialog';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { UserPage } from './routes/user/UserPage';
import { common } from '@kit.AbilityKit';
import { WebParams } from './common/WebBrowserPage';
import { TabAnimModifier } from '../utils/animation/TabAnimModifier';
import { AiFlowBackground } from './common/AIFlowBackground';
import { HuaweiAccountUtils } from '../utils/account/HuaweiAccountUtils';

interface TabData {
  title: string,
  icon: Resource,
  index: number
}

@Entry
@Component
struct Index {
  // 全局路由栈
  @Provide('appPathStack') appPathStack: NavPathStack = new NavPathStack();
  @Provide('isAiFlowShown') isAiFlowShown: boolean = false;

  @StorageProp('IsAppDataReady') @Watch('onDataReady') isAppDataReady: boolean = false;
  @State isShowUI: boolean = false;

  @StorageLink('isLoggedIn') @Watch('onLoginStatusChange') isLoggedIn: boolean = false;
  @State hasCheckedProfile: boolean = false;

  @StorageLink('QuickAddTaskTrigger') @Watch('onQuickAddTrigger') quickAddTrigger: boolean = false;

  onQuickAddTrigger() {
    if (this.quickAddTrigger === true) {
      this.currentIndex = 0;
    }
  }

  private context = getContext(this) as common.UIAbilityContext;
  private privacyUrl: string = 'resource://rawfile/privacy_agreement.html';

  @State isBlocking: boolean = false;
  private isDialogOpened: boolean = false;

  dialogController: CustomDialogController | null = new CustomDialogController({
    builder: PrivacyDialog({
      onConfirm: async () => {
        await LocalValues.getInstance().setPrivacyAgreed();
        this.isBlocking = false;
        this.isDialogOpened = false;
        console.info('User agreed to privacy policy.');
      },
      onCancel: () => {
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      },
      onJumpToWeb: () => {
        this.isDialogOpened = false;
        this.openPrivacyWeb();
      },
    }),
    autoCancel: false,
    alignment: DialogAlignment.Center,
    cancel: () => {
      if (this.isBlocking) {
        this.context.terminateSelf().catch(() => {
          console.error('Terminate failed');
        });
      }
    }
  })

  onDataReady() {
    if (this.isAppDataReady) {
      animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
        this.isShowUI = true;
      });
    }
  }

  aboutToAppear() {
    if (this.isAppDataReady) {
      this.onDataReady();
    }

    if (this.isLoggedIn) {
      this.checkAndRepairUserProfile();
    }

    this.checkAndShowDialog();
  }

  onPageShow() {
    if (this.isLoggedIn && !this.hasCheckedProfile) {
      this.checkAndRepairUserProfile();
    }
  }

  onLoginStatusChange() {
    if (this.isLoggedIn) {
      this.checkAndRepairUserProfile();
    }
  }

  /**
   * 核心修复逻辑：
   * 检测是否属于“已登录但未授权”的用户，如果是，则强制弹窗。
   */
  async checkAndRepairUserProfile() {
    if (this.hasCheckedProfile) return;
    this.hasCheckedProfile = true;

    const ctx = this.getUIContext().getHostContext();
    if (!ctx) return;

    try {
      const sysProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx, false);

      if (!sysProfile.nickname || sysProfile.nickname.trim() === '') {
        console.info('[Fix] Detect logged-in user with missing profile. Triggering Force Auth...');

        const fixedProfile = await HuaweiAccountUtils.getHuaweiAccountProfile(ctx, true);

        if (fixedProfile.nickname) {
          console.info('[Fix] User repaired successfully.');
          promptAction.showToast({ message: '用户信息已同步' });
        }
      } else {
        console.info('[Fix] User profile is healthy.');
      }
    } catch (e) {
      console.error('[Fix] Profile check failed:', e);
    }
  }

  async checkAndShowDialog() {
    const isAgreed = await LocalValues.getInstance().getIsPrivacyAgreed();
    if (!isAgreed && !this.isDialogOpened) {
      this.isBlocking = true;
      this.dialogController?.open();
    }
  }

  openPrivacyWeb() {
    const params: WebParams = {
      url: this.privacyUrl,
      title: '隐私协议',
      onClose: () => {
        console.info('WebBrowserPage is closing, re-checking privacy...');
        setTimeout(() => {
          this.checkAndShowDialog();
        }, 100);
      }
    };

    this.appPathStack.pushPath({
      name: 'webBrowser',
      param: params,
    });
  }

  onBackPress() {
    if (this.isBlocking) {
      return true; // 返回 true 表示“我已处理该事件”，系统不会执行默认的退出操作
    }
    return false;
  }

  @State currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  // 用于控制三个 Tab 的动画触发状态 (0: 初始, 每次点击增加以触发动画)
  @State tabAnimationTriggers: number[] = [0, 0, 0];

  // 定义 Tab 数据
  private tabs: Array<TabData> = [
    { title: '主页', icon: $r('sys.symbol.house_fill_1'), index: 0 },
    // { title: '概览', icon: $r('sys.symbol.square_fill_grid_2x2'), index: 1 },
    { title: '概览', icon: $r('sys.symbol.data_proportion_fill'), index: 1 },
    { title: '我的', icon: $r('sys.symbol.person_crop_circle_fill_1'), index: 2 },
  ]

  private getTabBarStyle(item: TabData): BottomTabBarStyle {
    let style = BottomTabBarStyle.of(
      this.getTabBarSymbol(item.icon),
      item.title
    );

    style.labelStyle({
      selectedColor: $r('app.color.brand'),
      unselectedColor: $r('app.color.font_secondary')
    })

    return style;
  }

  private getTabBarSymbol(icon: Resource): TabBarSymbol {
    return {
      normal: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([$r('app.color.font_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY),

      selected: new SymbolGlyphModifier(icon)
        .fontSize(24)
        .fontColor([$r('app.color.brand')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .symbolEffect(
          new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN)
        )
    };
  }

  build() {
    Stack() {
      if (this.isShowUI) {
        HdsNavigation(this.appPathStack) {
          Tabs({
            barPosition: BarPosition.End,
            index: this.currentIndex,
            controller: this.tabsController
          }) {
            // --- Tab 1: 主页 ---
            TabContent() {
              MainHomePage({ currentTabIndex: this.currentIndex })
                .width("100%")
                .height("100%")
                .attributeModifier(new TabAnimModifier(0, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
            }
            .tabBar(this.getTabBarStyle(this.tabs[0]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .backgroundColor($r('app.color.background_primary'))

            // --- Tab 2: 概览 ---
            TabContent() {
              OverviewPage({ currentTabIndex: this.currentIndex })
                .attributeModifier(new TabAnimModifier(1, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
            }
            .tabBar(this.getTabBarStyle(this.tabs[1]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .backgroundColor($r('app.color.background_primary'))

            // --- Tab 3: 我的 ---
            TabContent() {
              UserPage()
                .attributeModifier(new TabAnimModifier(2, this.currentIndex))
                .animation({
                  duration: 300, // 保持与 Tabs 动画时长一致
                  curve: Curve.EaseInOut
                })
            }
            .tabBar(this.getTabBarStyle(this.tabs[2]))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .backgroundColor($r('app.color.background_primary'))
          }
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .barMode(BarMode.Fixed) // 固定布局
          .barOverlap(true) // TabBar 与内容叠加，方便做模糊
          .background($r('app.color.background_primary'))
          // .barBackgroundColor(Color.Transparent)
          .animationDuration(300)
          .scrollable(false) // 两个 Tab 不需要横向滚动
          // .barHeight(48)
          .height('100%')
          .width('100%')
          .onChange((index: number) => {
            this.currentIndex = index;
          })
          .onTabBarClick((index: number) => {
            this.tabAnimationTriggers[index] += 1;

            if (index === this.currentIndex) {
              console.debug(`[MainPage] 重复点击了第 ${index} 页，触发回到顶部`);
              AppStorage.setOrCreate(`Event_ScrollToTop_${index}`, Date.now());
            }
          })
        }
        .hideTitleBar(true)
        .transition(TransitionEffect.OPACITY.animation({ duration: 400, curve: Curve.EaseOut }))
        // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      }

      if (this.isAiFlowShown) {
        AiFlowBackground()
          .height('110%')
          .width('100%')
          .hitTestBehavior(HitTestMode.None)
          .zIndex(999)
          .transition(TransitionEffect.OPACITY.animation({ duration: 500 }))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .height('100%')
    .width('100%')
  }
}