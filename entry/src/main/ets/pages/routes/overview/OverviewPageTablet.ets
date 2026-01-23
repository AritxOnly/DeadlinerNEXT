import { HdsNavigation, HdsNavigationTitleMode, HdsNavigationAttribute } from "@kit.UIDesignKit";
import { LengthMetrics, SegmentButtonOptions } from "@kit.ArkUI";
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DDLItem, DeadlineType } from '../../../model/DDLModels';
import {
  isOverdue, isToday, extractTimeBucket, bucketOrder,
  computeDailyCompletedCounts, computeMonthlyTaskStats, computeWeeklyCompletedCounts,
  DailyStat, MonthlyStat, WeeklyStat
} from '../../../utils/OverviewUtils'
import { DashboardSection } from "./DashboardSection";
import { OverviewStatsSection } from "./OverviewStatsSection";
import { TrendAnalysisSection } from "./TrendAnalysisSection";
import { getImmersiveTitleBarStyle } from "../../../common/style/NavStyles";

@Component
export struct OverviewPageTablet {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  // --- 状态控制 ---
  @State isLoading: boolean = true;

  // 独立的弹窗状态控制
  @State isOverviewHelpShow: boolean = false;
  @State isTrendHelpShow: boolean = false;
  @State isDashboardHelpShow: boolean = false;

  // --- 数据源 ---
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

  aboutToAppear(): void {
    this.loadData();
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

      // 更新状态
      this.todayCompleted = completedItems.length;
      this.todayTodo = incompleteItems.length;
      this.todayOverdue = todayOverdueItems.length;

      const newHistoryStats = new Map<string, number>();
      newHistoryStats.set('累计完成', historyCompleted.length);
      newHistoryStats.set('当前待办', historyIncomplete.length);
      newHistoryStats.set('累计逾期', historyOverdue.length);
      this.historyStats = newHistoryStats;

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

      this.dailyStats = computeDailyCompletedCounts(items, 7);
      this.monthlyStats = computeMonthlyTaskStats(items, 6);
      this.weeklyStats = computeWeeklyCompletedCounts(items, 4);
    } catch (e) {
      console.error(`[OverviewPage] Load data error: ${e}`);
    } finally {
      this.isLoading = false;
    }
  }

  // --- 独立的 Popup Builders ---

  @Builder OverviewHelpBuilder() {
    Column({ space: 8 }) {
      Text("概览说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 完成分布：").fontWeight(FontWeight.Medium)
        Span("统计任务完成的时间段，柱状图越长代表该时段完成任务越多。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 历史统计：").fontWeight(FontWeight.Medium)
        Span("点击环形图扇区，中间圆环内将显示该状态的具体数值。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder TrendHelpBuilder() {
    Column({ space: 8 }) {
      Text("趋势说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 本周情况：").fontWeight(FontWeight.Medium)
        Span("展示每日完成任务数。点击右上角").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("「显示逾期」").fontColor($r('app.color.chart_red'))
        Span("开关，可对比每日逾期数量。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 每月趋势：").fontWeight(FontWeight.Medium)
        Span("展示近12个月的任务总量、完成量及逾期量走势。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  @Builder DashboardHelpBuilder() {
    Column({ space: 8 }) {
      Text("看板说明")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .margin({ bottom: 4 })
      Text() {
        Span("• 数据汇总：").fontWeight(FontWeight.Medium)
        Span("基于您的所有任务数据计算出的关键指标。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
      Text() {
        Span("• 变化指标：").fontWeight(FontWeight.Medium)
        Span("箭头（").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("↑").fontColor($r('app.color.chart_green'))
        Span("/").fontColor($r('sys.color.ohos_id_color_text_secondary'))
        Span("↓").fontColor($r('app.color.chart_red'))
        Span("）代表与上周期相比的变化幅度。").fontColor($r('sys.color.ohos_id_color_text_secondary'))
      }.fontSize(14).lineHeight(20)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .borderRadius(12)
    .width(280)
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (!this.isLoading) {
          Row() {
            // === 第一栏：概览统计 ===
            Column() {
              Row() {
                Text('概览统计')
                  .fontSize(14) // [修复] 字体调小
                  .fontWeight(FontWeight.Medium) // [修复] 字重调轻
                  .fontColor($r('app.color.font_secondary')) // [修复] 颜色调淡

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18) // 图标也稍微调小适配标题
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isOverviewHelpShow = !this.isOverviewHelpShow
                })
                .bindPopup(this.isOverviewHelpShow, {
                  builder: this.OverviewHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isOverviewHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              // 内容区
              Scroll() {
                Column() {
                  OverviewStatsSection({
                    todayCompleted: this.todayCompleted,
                    todayTodo: this.todayTodo,
                    todayOverdue: this.todayOverdue,
                    historyStats: $historyStats,
                    completionTimeStats: $completionTimeStats,
                    overdueItems: this.overdueItems
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')

            // --- 分割线 ---
            Divider()
              .vertical(true)
              .height('100%')
              .strokeWidth(1)
              .color($r('sys.color.ohos_id_color_list_separator'))
              .opacity(0.5)

            // === 第二栏：趋势分析 ===
            Column() {
              Row() {
                Text('趋势分析')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.font_secondary'))

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isTrendHelpShow = !this.isTrendHelpShow
                })
                .bindPopup(this.isTrendHelpShow, {
                  builder: this.TrendHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isTrendHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              Scroll() {
                Column() {
                  TrendAnalysisSection({
                    dailyStats: $dailyStats,
                    monthlyStats: $monthlyStats,
                    weeklyStats: $weeklyStats
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')

            // --- 分割线 ---
            Divider()
              .vertical(true)
              .height('100%')
              .strokeWidth(1)
              .color($r('sys.color.ohos_id_color_list_separator'))
              .opacity(0.5)

            // === 第三栏：月度总结（看板） ===
            Column() {
              Row() {
                Text('月度总结')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.font_secondary'))

                Blank()

                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.questionmark_circle'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28)
                .height(28)
                .backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.isDashboardHelpShow = !this.isDashboardHelpShow
                })
                .bindPopup(this.isDashboardHelpShow, {
                  builder: this.DashboardHelpBuilder,
                  placement: Placement.BottomRight,
                  mask: false,
                  enableArrow: true,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.isDashboardHelpShow = false
                    }
                  }
                })
              }
              .width('100%')
              .padding({ left: 24, right: 24 })
              .alignItems(VerticalAlign.Center)

              Scroll() {
                Column() {
                  DashboardSection({
                    items: this.allItems
                  })
                }
                .padding({ bottom: 24 })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.statusBarHeight + 16 })
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
      style: getImmersiveTitleBarStyle(true),
      content: {
        title: { mainTitle: '概览' }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .mode(NavigationMode.Stack)
    .navBarWidth('100%')
    .padding({ top: this.statusBarHeight })
  }
}