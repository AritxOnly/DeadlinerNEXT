import { HdsNavigation, HdsNavigationAttribute, } from '@hms.hds.hdsBaseComponent';
import { LengthMetrics } from '@kit.ArkUI';
import { MainHomePage } from './routes/main/MainHomePage';
import { OverviewPage } from './routes/overview/OverviewPage';
import { AiPage } from './routes/ai/AIPage';
import { UserPage } from './routes/user/UserPage';

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

  @Builder
  private tabItem(item: TabData) {
    Column({ space: 2 }) {
      SymbolGlyph(item.icon)
        .fontSize(24)
        .fontColor([
          this.currentIndex === item.index
            ? $r('app.color.brand')
            : $r('app.color.font_secondary'),
        ])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .symbolEffect(
          new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.DOWN),
          this.tabAnimationTriggers[item.index]
        )

      Text(item.title)
        .fontSize(10)
        .fontColor(
          this.currentIndex === item.index
            ? $r('app.color.brand')
            : $r('app.color.font_secondary')
        )
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
        .tabBar(this.tabItem(this.tabs[0]))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // --- Tab 2: 概览 ---
        TabContent() {
          OverviewPage()
        }
        .tabBar(this.tabItem(this.tabs[1]))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        // --- Tab 3: 我的 ---
        TabContent() {
          UserPage()
        }
        .tabBar(this.tabItem(this.tabs[2]))
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