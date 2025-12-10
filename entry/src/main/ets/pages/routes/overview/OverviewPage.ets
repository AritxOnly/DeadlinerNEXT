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

  readonly SEGMENT_HEIGHT: number = 44;
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

  // --- 弹窗控制器 ---
  settingsDialogController: CustomDialogController = new CustomDialogController({
    builder: OverviewSettingsDialog(),
    alignment: DialogAlignment.Center,
    customStyle: true
  })

  // --- Tab 配置 ---
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '总览' },
      { text: '趋势' },
      { text: '上月' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 8
  })

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

  build() {
    HdsNavigation() {
      Stack() {
        // [核心修改] 使用 if (!this.isLoading)
        // 确保数据准备好后，子组件才开始创建 (mount)
        // 这样子组件的 aboutToAppear 能直接读到正确的数据，完美解决 0 0 0 和图表空白

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

          // 加载动画
          if (this.isLoading) {
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
        menu: {
          value: [
            {
              content: {
                label: 'Settings',
                icon: $r('sys.symbol.gearshape'),
                action: () => {
                  this.settingsDialogController.open();
                }
              }
            }
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
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}