import { LocalValues } from '../../../common/local/LocalValues';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DDLItem, DeadlineType } from '../../../model/DDLModels';
import {
  isToday, isOverdue, extractTimeBucket, bucketOrder,
  computeDailyCompletedCounts, computeMonthlyTaskStats, computeWeeklyCompletedCounts,
  DailyStat, MonthlyStat, WeeklyStat,
  generateDashboardMetrics, Metric
} from '../../../utils/OverviewUtils';

// 1. 定义卡片 ID (为下一步拖拽排序做准备)
export enum OverviewCard {
  ACTIVE_STATS = 'ACTIVE_STATS',       // 今日概况
  COMPLETION_TIME = 'COMPLETION_TIME', // 完成时间分布
  HISTORY_STATS = 'HISTORY_STATS'      // 历史统计
}

export enum TrendCard {
  DAILY_TREND = 'DAILY_TREND',     // 本周完成
  MONTHLY_TREND = 'MONTHLY_TREND', // 每月趋势
  WEEKLY_TREND = 'WEEKLY_TREND'    // 近4周完成
}

@Observed
export class OverviewViewModel {
  // --- UI 状态 ---
  public isLoading: boolean = true;

  // --- Snapshot 数据 ---
  public todayCompleted: number = 0;
  public todayTodo: number = 0;
  public todayOverdue: number = 0;
  public historyStats: Map<string, number> = new Map();
  public completionTimeStats: Array<[string, number]> = [];
  public overdueItems: DDLItem[] = [];

  // --- Trend 数据 ---
  public dailyStats: DailyStat[] = [];
  public monthlyStats: MonthlyStat[] = [];
  public weeklyStats: WeeklyStat[] = [];

  // --- Dashboard 数据 ---
  public allItems: DDLItem[] = []; // Dashboard 需要原始数据

  // --- 排序配置 (为拖拽做准备，目前存默认顺序) ---
  public overviewCardOrder: OverviewCard[] = [
    OverviewCard.ACTIVE_STATS,
    OverviewCard.COMPLETION_TIME,
    OverviewCard.HISTORY_STATS
  ];

  public trendCardOrder: TrendCard[] = [
    TrendCard.DAILY_TREND,
    TrendCard.MONTHLY_TREND,
    TrendCard.WEEKLY_TREND
  ];

  constructor() {
    this.loadSortOrder();
  }

  /**
   * 加载本地排序配置
   */
  private loadSortOrder() {
    const localVals = LocalValues.getInstance();

    // 读取概览页顺序
    const savedOverview = localVals.getOverviewCardOrder();
    if (savedOverview && savedOverview.length > 0) {
      // 强转 string[] 为 enum[] (只要存储时没存错字符串就行)
      this.overviewCardOrder = savedOverview as OverviewCard[];
    }

    // 读取趋势页顺序
    const savedTrend = localVals.getTrendCardOrder();
    if (savedTrend && savedTrend.length > 0) {
      this.trendCardOrder = savedTrend as TrendCard[];
    }
  }

  // 原封不动搬运过来的数据加载逻辑
  public async loadData() {
    this.isLoading = true;

    try {
      // 1. 获取数据
      const items = await TaskRepository.getInstance().getDDLsByType(DeadlineType.TASK);
      this.allItems = items;

      // 2. 数据处理
      const activeItems = items.filter(it => !it.isArchived);

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
      console.error(`[OverviewViewModel] Load data error: ${e}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 处理卡片移动并持久化
   */
  public onCardMove(tab: 'OVERVIEW' | 'TREND', from: number, to: number) {
    if (tab === 'OVERVIEW') {

      const newOrder = [...this.overviewCardOrder];
      // 2. 在新数组上操作
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      // 3. 重新赋值给属性 (这步是触发 @Link 刷新的关键)
      this.overviewCardOrder = newOrder;

      // 保存到本地
      LocalValues.getInstance().setOverviewCardOrder(this.overviewCardOrder);

    } else {
      // 趋势页同理
      const newOrder = [...this.trendCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.trendCardOrder = newOrder;

      LocalValues.getInstance().setTrendCardOrder(this.trendCardOrder);
    }
  }

  public moveItemInMemory(tab: 'OVERVIEW' | 'TREND', from: number, to: number) {
    if (from === to) return;

    if (tab === 'OVERVIEW') {
      const newOrder = [...this.overviewCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.overviewCardOrder = newOrder; // 触发 UI 刷新
    } else {
      const newOrder = [...this.trendCardOrder];
      const item = newOrder[from];
      newOrder.splice(from, 1);
      newOrder.splice(to, 0, item);
      this.trendCardOrder = newOrder; // 触发 UI 刷新
    }
  }

  public saveCurrentOrder() {
    LocalValues.getInstance().setOverviewCardOrder(this.overviewCardOrder);
    LocalValues.getInstance().setTrendCardOrder(this.trendCardOrder);
  }
}