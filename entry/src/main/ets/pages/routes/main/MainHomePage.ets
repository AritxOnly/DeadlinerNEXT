import { ItemRestriction, LengthMetrics, SegmentButton,
  SegmentButtonItemTuple,
  SegmentButtonOptions,
  SegmentButtonTextItem,
  Theme } from '@kit.ArkUI'
import { HomeFloatingToolbar } from '../../components/HomeFloatingToolbar'
import { HabitListSection } from './HabitListSection'
import { TaskListSection } from './TaskListSection'
import { BottomBuilderShowType,
  DividerShowType,
  HdsNavDestination,
  HdsNavigation, HdsNavigationAttribute,
  HdsNavigationTitleMode,
  ScrollEffectType,
  TextStyleMode} from '@kit.UIDesignKit'
import { TaskListController } from './TaskListController'
import { ConfettiController } from '../../components/confetti/ConfettiController'
import { ConfettiView } from '../../components/confetti/ConfettiView'
import { AIPanelView } from '../../components/AIPanelView'

enum MainTabIndex {
  TASKS = 0,
  HABITS = 1,
  SUGGESTS = 2
}

const EXCITEMENT_MESSAGES: Resource[] = [
  $r('app.string.excitement_deadline_chasing'),
  $r('app.string.excitement_progress_1_to_99'),
  $r('app.string.excitement_ddl_bite'),
  $r('app.string.excitement_submit'),
  $r('app.string.excitement_get_up'),
  $r('app.string.excitement_5min_5h'),
  $r('app.string.excitement_todo_on_fire'),
  $r('app.string.excitement_today_task'),
  $r('app.string.excitement_ddl_near'),
  $r('app.string.excitement_classic_flag'),
  $r('app.string.excitement_reward_sleep'),
  $r('app.string.excitement_detect_anxiety'),
  $r('app.string.excitement_stop_scrolling'),
  $r('app.string.excitement_last_minute'),
  $r('app.string.excitement_mountains'),
  $r('app.string.excitement_ddl_power'),
  $r('app.string.excitement_im_okay'),
  $r('app.string.excitement_today_achievement'),
  $r('app.string.excitement_do_hard_first'),
  $r('app.string.excitement_next'),
]

@Component
export struct MainHomePage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @State currentIndex: number = MainTabIndex.TASKS
  @State @Watch('onSegmentChange') selectedIndexes: number[] = [MainTabIndex.TASKS]

  @State isTaskSelectionMode: boolean = false;
  private taskController: TaskListController = new TaskListController();

  @State confettiController: ConfettiController = new ConfettiController();

  // 定义常量：SegmentButton 区域的高度 (标准高度 + 上下padding)
  readonly SEGMENT_HEIGHT: number = 44;

  // 获取状态栏高度
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 100 + this.SEGMENT_HEIGHT;

  // 这些 State 由主题驱动
  @State chipSelectedBg: ResourceColor = '#FFFFFF'
  @State chipSelectedFont: ResourceColor = '#000000'
  @State chipUnselectedFont: ResourceColor = '#00000099'
  @State pageBackground: ResourceColor = '#FFFFFFFF'
  @State fabBg: ResourceColor = '#6E8B74'
  @State fabIconColor: ResourceColor = '#FFFFFFFF'

  onWillApplyTheme(theme: Theme) {
    this.chipSelectedBg = theme.colors.interactiveSelect
    this.chipSelectedFont = theme.colors.fontPrimary
    this.chipUnselectedFont = theme.colors.fontSecondary
    this.pageBackground = theme.colors.backgroundPrimary
    this.fabBg = theme.colors.interactiveActive
    this.fabIconColor = theme.colors.iconEmphasize
  }

  @State navSubtitle: string | undefined = undefined

  aboutToAppear(): void {
    const ctx = this.getUIContext()
    const idx = Math.floor(Math.random() * EXCITEMENT_MESSAGES.length)
    const res = EXCITEMENT_MESSAGES[idx]
    try {
      this.navSubtitle = ctx.getHostContext()?.resourceManager.getStringSync(res)
    } catch (error) {
      console.error('Unable to get String Resource')
    }
  }

  private scroller: Scroller = new Scroller();

  @StorageProp('Event_ScrollToTop_0')
  @Watch('onScrollToTopEvent')
  scrollToTopSignal: number = 0;

  onScrollToTopEvent() {
    console.debug('MainHomePage received scroll to top signal');
    // 只有当前页面显示时才滚动
    if (this.currentIndex === MainTabIndex.TASKS) { // 假设你想让任务列表回滚
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 300 } });
    }
  }

  onSegmentChange() {
    if (this.selectedIndexes.length > 0) {
      this.currentIndex = this.selectedIndexes[0]
    }
  }

  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: '任务' }, { text: '习惯' }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 8
  })

  updateTabOptions() {
    this.tabOptions = SegmentButtonOptions.tab({
      buttons: [
        { text: '任务' },
        { text: '习惯' }
      ] as ItemRestriction<SegmentButtonTextItem>,
      backgroundBlurStyle: BlurStyle.NONE,
      selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
      buttonPadding: 8
    });
  }

  @Builder tabSegment() {
    Column() {
      SegmentButton({
        options: this.tabOptions,
        selectedIndexes: $selectedIndexes,
        maxFontScale: 2
      })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({
      start: LengthMetrics.vp(16), end: LengthMetrics.vp(16),
    })
    .justifyContent(FlexAlign.Center)
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
        RelativeContainer() {
          // 列表内容：铺满整个容器
          if (this.currentIndex === MainTabIndex.TASKS) {
            TaskListSection({
              scroller: this.scroller,
              topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT,
              isSelectionMode: $isTaskSelectionMode,
              controller: this.taskController,
              confetti: this.confettiController
            })
              .id('content')
              .alignRules({
                top: { anchor: '__container__', align: VerticalAlign.Top },
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                left: { anchor: '__container__', align: HorizontalAlign.Start },
                right: { anchor: '__container__', align: HorizontalAlign.End },
              })
          } else {
            HabitListSection({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT })
              .id('content')
              .alignRules({
                top: { anchor: '__container__', align: VerticalAlign.Top },
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                left: { anchor: '__container__', align: HorizontalAlign.Start },
                right: { anchor: '__container__', align: HorizontalAlign.End },
              })
          }

          ConfettiView({
            controller: this.confettiController,
            colors: ['#fce18a', '#ff726d', '#f4306d', '#b48def']
          })
            .hitTestBehavior(HitTestMode.None)
            .id('confetti')
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
            })
            .zIndex(1)

          if (this.currentIndex === MainTabIndex.TASKS) {
            HomeFloatingToolbar({
              isSelectionMode: this.isTaskSelectionMode,

              // 主按钮逻辑：多选时为关闭，平时为添加
              onClickAdd: () => {
                if (this.isTaskSelectionMode) {
                  this.taskController.requestExitSelection();
                } else {
                  this.appPathStack.pushPathByName('addTask', null);
                }
              },

              // 批量操作代理到 Controller
              handleBatchComplete: () => this.taskController.requestBatchComplete(),
              handleBatchArchive: () => this.taskController.requestBatchArchive(),
              handleBatchDelete: () => this.taskController.requestBatchDelete(),
              handleBatchEdit: () => this.taskController.requestBatchEdit()
            })
              .id('fab')
              .alignRules({
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                middle: { anchor: '__container__', align: HorizontalAlign.Center },
              })
              .margin({ bottom: 48 })
              .hitTestBehavior(HitTestMode.Transparent)
          } else {
            // 在其他 Tab (如 Habit) 显示普通 FAB，或者根据 Habit 需求复用 Toolbar
            HomeFloatingToolbar({
              isSelectionMode: false, // 习惯暂无多选
              onClickAdd: () => { /* Add Habit Logic */ },
              handleBatchComplete: () => {},
              handleBatchArchive: () => {},
              handleBatchDelete: () => {},
              handleBatchEdit: () => {}
            })
              .id('fab_habit')
              .alignRules({
                bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
                middle: { anchor: '__container__', align: HorizontalAlign.Center },
              })
              .margin({ bottom: 48 })
          }
        }
        .height('100%')
        .width('100%')
        .backgroundColor(this.pageBackground)
    }
    .titleBar({
      style: {
        // --- 核心：滚动动态模糊配置 ---
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
        }
      },
      content: {
        // --- 标题内容 ---
        title: {
          mainTitle: 'Deadliner',
          subTitle: this.navSubtitle
        },
        // --- 菜单按钮 ---
        menu: {
          value: [
            {
              content: {
                label: 'AI',
                icon: $r('sys.symbol.wand_and_stars'),
                action: () => {
                  this.isAISheetShow = true
                }
              }
            },
            {
              content: {
                label: 'Search',
                icon: $r('sys.symbol.magnifyingglass'), // 使用系统 Symbol
                action: () => {
                  // TODO: 搜索逻辑
                }
              }
            },
          ]
        },
        bottomBuilder: {
          builder: this.tabSegment.bind(this),
          height: this.SEGMENT_HEIGHT,
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        divider: { showType: DividerShowType.OFF }
      }
    })
    .bindSheet($$this.isAISheetShow, this.aiSheet(), {
      height: SheetSize.LARGE,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
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
    .titleMode(HdsNavigationTitleMode.FREE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}