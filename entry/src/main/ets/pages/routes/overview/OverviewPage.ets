import { BottomBuilderShowType, DividerShowType, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, HdsNavigationAttribute } from "@kit.UIDesignKit";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { ItemRestriction, LengthMetrics, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem, router, promptAction } from "@kit.ArkUI";
import { OverviewSettingsDialog } from '../../components/OverviewSettingsDialog';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DDLItem, DeadlineType } from '../../../model/DDLModels';
import {
  hashColor, safeParseDate, isOverdue, isToday, extractTimeBucket, bucketOrder,
  computeDailyCompletedCounts, computeMonthlyTaskStats, computeWeeklyCompletedCounts,
  DailyStat, MonthlyStat, WeeklyStat
} from '../../../utils/OverviewUtils'
import { DashboardSection } from "./DashboardSection";
import { OverviewStatsSection } from "./OverviewStatsSection";
import { TrendAnalysisSection } from "./TrendAnalysisSection";

@Component
export struct OverviewPage {
  @Consume('appPathStack') appPathStack: NavPathStack;

  readonly SEGMENT_HEIGHT: number = 48;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  // --- 状态控制 ---
  @State selectedIndexes: number[] = [0];
  @State isLoading: boolean = true;

  // --- 数据源 ---

  // [修改 1] 将 activeStats Map 拆解为 3 个具体的数字状态
  // 这样传给子组件时是值传递，UI 刷新 100% 稳定
  @State todayCompleted: number = 0;
  @State todayTodo: number = 0;
  @State todayOverdue: number = 0;
  @State historyStats: Map<string, number> = new Map();
  @State completionTimeStats: Array<[string, number]> = [];
  @State overdueItems: DDLItem[] = [];

  @State dailyStats: DailyStat[] = [];
  @State monthlyStats: MonthlyStat[] = [];
  @State weeklyStats: WeeklyStat[] = [];

  @State allItems: DDLItem[] = [];

  // --- Tab 配置 ---
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '总览' },
      { text: '趋势' },
      { text: '上月' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 10
  })

  aboutToAppear(): void {
    this.loadData();
  }

  @Prop @Watch('onTabSwitch') currentTabIndex: number = 0;

  readonly TARGET_INDEX: number = 1;

  onTabSwitch() {
    if (this.currentTabIndex === this.TARGET_INDEX) {
      console.debug('[OverviewPage] Tab switched to Overview. Reloading data...');
      this.loadData();
      this.selectedIndexes[0] = 0;
    } else {
    }
  }

  async loadData() {
    this.isLoading = true;

    try {
      // 1. 获取数据
      const items = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);

      this.allItems = items;

      // 2. 数据处理
      const activeItems = items.filter(it => !it.isArchived);

      // 筛选各类条目
      const completedItems = activeItems.filter(it => it.isCompleted && isToday(it.completeTime));
      const incompleteItems = activeItems.filter(it => !it.isCompleted && !isOverdue(it));
      const todayOverdueItems = activeItems.filter(it => !it.isCompleted && isToday(it.endTime) && isOverdue(it));

      const historyCompleted = items.filter(it => it.isCompleted);
      const historyIncomplete = items.filter(it => !it.isCompleted);
      const historyOverdue = activeItems.filter(it => isOverdue(it));

      // [修改 3] 更新拆分后的状态 (简单数字)
      this.todayCompleted = completedItems.length;
      this.todayTodo = incompleteItems.length;
      this.todayOverdue = todayOverdueItems.length;

      // [修改 4] 更新 Map (使用 new Map 确保触发更新)
      const newHistoryStats = new Map<string, number>();
      newHistoryStats.set('累计完成', historyCompleted.length);
      newHistoryStats.set('当前待办', historyIncomplete.length);
      newHistoryStats.set('累计逾期', historyOverdue.length);
      this.historyStats = newHistoryStats;

      // [修改 5] 更新 Array
      const bucketMap = new Map<string, number>();
      historyCompleted.forEach(it => {
        const bucket = extractTimeBucket(it.completeTime);
        const count = bucketMap.get(bucket) || 0;
        bucketMap.set(bucket, count + 1);
      });

      const sortedBuckets = Array.from(bucketMap.entries()).sort((a, b) => {
        return (bucketOrder[a[0]] || 99) - (bucketOrder[b[0]] || 99);
      });
      this.completionTimeStats = sortedBuckets;

      this.overdueItems = historyOverdue;

      this.dailyStats = computeDailyCompletedCounts(items, 7);   // 过去7天
      this.monthlyStats = computeMonthlyTaskStats(items, 6);     // 过去6个月 (防止手机屏太挤)
      this.weeklyStats = computeWeeklyCompletedCounts(items, 4); // 过去4周
    } catch (e) {
      console.error(`[OverviewPage] Load data error: ${e}`);
    } finally {
      // 结束加载
      this.isLoading = false;
    }
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
    .padding({ start: LengthMetrics.vp(16), end: LengthMetrics.vp(16) })
    .justifyContent(FlexAlign.Center)
  }

  @State isHelpPopupShow: boolean = false

  @Builder helpPopupBuilder() {
    Column({ space: 8 }) {
      if (this.selectedIndexes[0] === 0) {
        // === 0: OverviewStatsSection (概览) ===
        Text("概览说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        // 1. 完成分布 (CompletionTimeCard)
        Text() {
          Span("• 完成分布：").fontWeight(FontWeight.Medium)
          Span("统计任务完成的时间段（如深夜、上午等），柱状图越长代表该时段完成任务越多。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 2. 历史统计 (HistoryStatsCard)
        Text() {
          Span("• 历史统计：").fontWeight(FontWeight.Medium)
          Span("点击环形图扇区").fontColor($r('sys.color.ohos_id_color_text_primary')) // Highlight interaction
          Span("，中间圆环内将显示该状态（完成/待办/逾期）的具体数值。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

      } else if (this.selectedIndexes[0] === 1) {
        // === 1: TrendAnalysisSection (趋势) ===
        Text("趋势说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        // 1. 本周情况 (DailyCompletedCard)
        Text() {
          Span("• 本周情况：").fontWeight(FontWeight.Medium)
          Span("展示每日完成任务数。点击右上角").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("「显示逾期」").fontColor($r('app.color.chart_red')) // Highlight specific UI element
          Span("开关，可对比每日逾期数量。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 2. 每月趋势 (MonthlyTrendCard)
        Text() {
          Span("• 每月趋势：").fontWeight(FontWeight.Medium)
          Span("展示近12个月的任务总量、完成量及逾期量走势，帮助您分析长期效率变化。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        // 3. 近4周完成 (PrevWeeksCard)
        Text() {
          Span("• 近4周完成：").fontWeight(FontWeight.Medium)
          Span("对比最近4周的周完成量，直观查看短期内的效率波动。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

      } else if (this.selectedIndexes[0] === 2) {
        // === 2: DashboardSection (看板) ===
        Text("看板说明")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ bottom: 4 })

        Text() {
          Span("• 数据汇总：").fontWeight(FontWeight.Medium)
          Span("基于您的所有任务数据计算出的关键指标（如总任务数、平均耗时等）。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)

        Text() {
          Span("• 变化指标：").fontWeight(FontWeight.Medium)
          Span("部分指标显示的箭头（").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("↑").fontColor($r('app.color.chart_green'))
          Span("/").fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Span("↓").fontColor($r('app.color.chart_red'))
          Span("）代表与上周期相比的变化幅度。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }.fontSize(14).lineHeight(20)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder titleMenuBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Row({ space: 8 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(24)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .onClick(() => {
          this.isHelpPopupShow = true;
        })
        .bindPopup(this.isHelpPopupShow, {
          builder: this.helpPopupBuilder,
          placement: Placement.Bottom,    // 气泡位置
          mask: false,
          backgroundBlurStyle: BlurStyle.Regular,
          enableArrow: true,
          onStateChange: (e) => {
            if (!e.isVisible) {
              this.isHelpPopupShow = false
            }
          }
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.End)
      .padding({ right: 16 })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .height('100%')
    .width('100%')
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (!this.isLoading) {
          TopSafeContainer({
            topAvoidHeight: this.statusBarHeight + this.SEGMENT_HEIGHT
          }) {
            if (this.selectedIndexes[0] === 0) {
              OverviewStatsSection({
                todayCompleted: this.todayCompleted,
                todayTodo: this.todayTodo,
                todayOverdue: this.todayOverdue,
                historyStats: $historyStats,
                completionTimeStats: $completionTimeStats,
                overdueItems: this.overdueItems
              })
            } else if (this.selectedIndexes[0] === 1) {
              TrendAnalysisSection({
                dailyStats: $dailyStats,
                monthlyStats: $monthlyStats,
                weeklyStats: $weeklyStats
              })
            } else if (this.selectedIndexes[0] === 2) {
              DashboardSection({
                items: this.allItems
              })
            }
          }
        } else {
          Column() {
            LoadingProgress()
              .width(64)
              .height(64)
              .color($r('sys.color.ohos_id_color_text_primary'))
            Text("正在加载数据...")
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
        }
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
        originalStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
        },
        scrollEffectStyle: {
          backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_navigation_background_blur') },
        }
      },
      content: {
        title: { mainTitle: '概览' },
        stackBuilder: this.titleMenuBuilder.bind(this),
        bottomBuilder: {
          builder: this.tabSegment.bind(this),
          height: this.SEGMENT_HEIGHT,
          showType: BottomBuilderShowType.DIRECTLY_SHOW
        },
        // divider: { showType: DividerShowType.OFF }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .navBarWidth('100%')
  }
}