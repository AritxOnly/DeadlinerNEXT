export interface KmpOverviewSummary {
  completedToday: number;
  pendingDueFromNow: number;
  overdueToday: number;
  activeAbandoned: number;
}

export interface KmpOverviewHistory {
  completed: number;
  pending: number;
  abandoned: number;
  overdue: number;
}

export interface KmpOverviewCompletionBucket {
  period: string;
  completedCount: number;
}

export interface KmpOverviewDailyStat {
  date: string;
  completedCount: number;
  overdueCount: number;
}

export interface KmpOverviewMonthlyStat {
  monthStart: string;
  totalCount: number;
  completedCount: number;
  overdueCompletedCount: number;
}

export interface KmpOverviewWeeklyStat {
  weekStart: string;
  completedCount: number;
}

export interface KmpOverviewContributionDay {
  date: string;
  completedCount: number;
}

export interface KmpOverviewMonthlyMetrics {
  totalTasks: number;
  completedTasks: number;
  completionRate: number;
  overdueTasks: number;
  mostActivePeriod?: string | null;
  mostActivePeriodCompletedCount: number;
  averageCompletionMinutes?: number | null;
  previousTotalTasks: number;
  previousCompletedTasks: number;
  previousCompletionRate: number;
  previousOverdueTasks: number;
}

export interface KmpOverviewLastMonth {
  monthStart?: string | null;
  daily: KmpOverviewDailyStat[];
  metrics: KmpOverviewMonthlyMetrics;
  completedTaskTitles: string[];
}

export interface KmpOverviewState {
  summary: KmpOverviewSummary;
  history: KmpOverviewHistory;
  completionBuckets: KmpOverviewCompletionBucket[];
  daily: KmpOverviewDailyStat[];
  monthly: KmpOverviewMonthlyStat[];
  weekly: KmpOverviewWeeklyStat[];
  contribution: KmpOverviewContributionDay[];
  lastMonth: KmpOverviewLastMonth;
  isLoading: boolean;
  error?: string | null;
}

export class KmpOverviewStateReader {
  public parse(payload: string): KmpOverviewState {
    const state: KmpOverviewState = JSON.parse(payload);
    return state;
  }
}
