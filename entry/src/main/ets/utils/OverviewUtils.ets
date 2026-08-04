/** Presentation-only chart contracts. All values are computed by KMP OverviewViewModel. */
export interface DailyStat {
  dateStr: string;
  fullDate: string;
  completed: number;
  overdue: number;
}

export interface MonthlyStat {
  monthStr: string;
  total: number;
  completed: number;
  overdue: number;
}

export interface WeeklyStat {
  weekLabel: string;
  completed: number;
}

export interface ContributionDay {
  date: Date;
  count: number;
}

export interface Metric {
  label: string;
  value: string;
  change?: string;
  isDown?: boolean;
}
