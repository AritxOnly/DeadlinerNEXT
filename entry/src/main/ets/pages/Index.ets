import { HdsNavigation, HdsNavigationAttribute, } from '@hms.hds.hdsBaseComponent';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { LocalValues } from '../common/local/LocalValues';
import { PrivacyDialog } from './components/PrivacyDialog';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { UserPage } from './routes/user/UserPage';
import { common } from '@kit.AbilityKit';
import { WebParams } from './common/WebBrowserPage';

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

  private context = getContext(this) as common.UIAbilityContext;
  private privacyUrl: string = 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1837914602910842752';

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

  async aboutToAppear() {
    this.checkAndShowDialog();
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
    // 如果当前处于“阻断”状态（即未同意协议），
    // 无论弹窗是否肉眼可见（哪怕因为跳转Web暂时关闭了），
    // 只要是在 Index 页面，都禁止通过返回键退出。
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
    { title: '概览', icon: $r('sys.symbol.square_fill_grid_2x2'), index: 1 },
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
    HdsNavigation(this.appPathStack) {
      Tabs({
        barPosition: BarPosition.End,
        index: this.currentIndex,
        controller: this.tabsController
      }) {
        // --- Tab 1: 主页 ---
        TabContent() {
          MainHomePage()
            .width("100%")
            .height("100%")
        }
        .tabBar(this.getTabBarStyle(this.tabs[0]))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // --- Tab 2: 概览 ---
        TabContent() {
          OverviewPage({ currentTabIndex: this.currentIndex })
        }
        .tabBar(this.getTabBarStyle(this.tabs[1]))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // --- Tab 3: 我的 ---
        TabContent() {
          UserPage()
        }
        .tabBar(this.getTabBarStyle(this.tabs[2]))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .barMode(BarMode.Fixed) // 固定布局
      .barOverlap(true) // TabBar 与内容叠加，方便做模糊
      .barBackgroundBlurStyle(BlurStyle.Regular) // TabBar 背景模糊（原生能力）
      .barBackgroundColor(Color.Transparent)
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
    // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}