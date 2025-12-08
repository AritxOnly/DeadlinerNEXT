import { BottomBuilderShowType, DividerShowType, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, HdsNavigationAttribute } from "@kit.UIDesignKit";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { ItemRestriction, LengthMetrics, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem, router, promptAction } from "@kit.ArkUI";
import { OverviewSettingsDialog } from '../../components/OverviewSettingsDialog';
import { TaskRepository } from '../../../data/repository/TaskRepository';
import { DDLItem, DeadlineType } from '../../../model/DDLModels';
import { hashColor, safeParseDate, isOverdue, isToday, extractTimeBucket, bucketOrder } from '../../../utils/OverviewUtils'
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

  // --- 数据源 (计算后的统计数据) ---
  @State activeStats: Map<string, number> = new Map();
  @State historyStats: Map<string, number> = new Map();
  @State completionTimeStats: Array<[string, number]> = [];
  @State overdueItems: DDLItem[] = []; // 专门传给 Dashboard 用于展示列表

  // --- 弹窗控制器 ---
  settingsDialogController: CustomDialogController = new CustomDialogController({
    builder: OverviewSettingsDialog(),
    alignment: DialogAlignment.Center,
    customStyle: true
  })

  // --- Tab 配置 ---
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '概览' },
      { text: '趋势' },
      { text: '汇总' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 8
  })

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData() {
    // [修改] 开始加载
    this.isLoading = true;

    try {
      // 1. 获取数据
      const items = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);

      // 2. 数据处理 (还原 Android OverviewScreen 的逻辑)
      const activeItems = items.filter(it => !it.isArchived);

      // 今日完成
      const completedItems = activeItems.filter(it => {
        return it.isCompleted && isToday(it.completeTime);
      });

      // 待办 (未完成且未逾期)
      const incompleteItems = activeItems.filter(it => !it.isCompleted && !isOverdue(it));

      // 今日逾期
      const todayOverdueItems = activeItems.filter(it => {
        return !it.isCompleted && isToday(it.endTime) && isOverdue(it);
      });

      // 历史数据
      const historyCompleted = items.filter(it => it.isCompleted);
      const historyIncomplete = items.filter(it => !it.isCompleted);
      const historyOverdue = activeItems.filter(it => isOverdue(it));

      // 3. 构建 Active Stats Map
      const newActiveStats = new Map<string, number>();
      newActiveStats.set('今日完成', completedItems.length);
      newActiveStats.set('待办任务', incompleteItems.length);
      newActiveStats.set('今日逾期', todayOverdueItems.length);
      this.activeStats = newActiveStats;

      // 4. 构建 History Stats Map
      const newHistoryStats = new Map<string, number>();
      newHistoryStats.set('累计完成', historyCompleted.length);
      newHistoryStats.set('当前待办', historyIncomplete.length);
      newHistoryStats.set('累计逾期', historyOverdue.length);
      this.historyStats = newHistoryStats;

      // 5. 趋势分析 (Time Buckets)
      const bucketMap = new Map<string, number>();
      historyCompleted.forEach(it => {
        const bucket = extractTimeBucket(it.completeTime);
        const count = bucketMap.get(bucket) || 0;
        bucketMap.set(bucket, count + 1);
      });

      // 转换成数组并排序
      const sortedBuckets = Array.from(bucketMap.entries()).sort((a, b) => {
        return (bucketOrder[a[0]] || 99) - (bucketOrder[b[0]] || 99);
      });
      this.completionTimeStats = sortedBuckets;

      // 6. 汇总数据 (Dashboard)
      this.overdueItems = historyOverdue;
    } catch (e) {
      console.error(`[OverviewPage] Load data error: ${e}`);
    } finally {
      // [修改] 无论成功失败，结束加载
      // 稍微延迟一下以防闪烁太快（可选，这里直接关）
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
      TopSafeContainer({
        topAvoidHeight: this.statusBarHeight + this.SEGMENT_HEIGHT
      }) {
        Column() {
          // 条件渲染显示不同内容
          if (this.selectedIndexes[0] === 0) {
            OverviewStatsSection({
              activeStats: this.activeStats,
              historyStats: this.historyStats,
              overdueItems: this.overdueItems,
              completionTimeStats: this.completionTimeStats
            })
          } else if (this.selectedIndexes[0] === 1) {
            TrendAnalysisSection({
              completionTimeStats: this.completionTimeStats
            })
          } else if (this.selectedIndexes[0] === 2) {
            DashboardSection({
              overdueItems: this.overdueItems
            })
          }
        }
        .width('100%')
        .height('100%')
        .padding({ top: 10 })
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