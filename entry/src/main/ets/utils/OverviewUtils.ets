import { DDLItem } from '../model/DDLModels';
import { List } from '@kit.ArkTS';

export function hashColor(key: string): ResourceColor {
  if (key.includes('今日') || key.includes('完成')) return $r('app.color.chart_green'); // Green
  if (key.includes('未完成')) return $r('app.color.chart_orange'); // Orange
  if (key.includes('逾期')) return $r('app.color.chart_red'); // Red
  return $r('app.color.chart_blue'); // Blue
}

export function safeParseDate(dateStr: string): Date {
  try {
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) {
      return new Date(dateStr.replace(/-/g, '/'));
    }
    return date;
  } catch (e) {
    return new Date();
  }
}

export function isOverdue(item: DDLItem): boolean {
  try {
    const end = safeParseDate(item.endTime);
    const now = new Date();
    return !item.isCompleted && (now.getTime() > end.getTime());
  } catch (e) {
    return false;
  }
}

export function isToday(dateStr: string): boolean {
  const d = safeParseDate(dateStr);
  const now = new Date();
  return d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
}

export function extractTimeBucket(completeTime: string): string {
  try {
    const time = safeParseDate(completeTime);
    const hour = time.getHours();
    if (hour >= 0 && hour < 6) return '深夜';
    if (hour >= 6 && hour < 12) return '上午';
    if (hour >= 12 && hour < 18) return '下午';
    if (hour >= 18 && hour <= 23) return '晚上';
    return '未知';
  } catch (e) {
    return '未知';
  }
}

// 时间段排序权重
export const bucketOrder: Record<string, number> = {
  '深夜': 0,
  '上午': 1,
  '下午': 2,
  '晚上': 3,
  '未知': 4
};

export interface DailyStat {
  dateStr: string;   // e.g., "12", "13" (日)
  fullDate: string;  // e.g., "2023-12-12" (用于调试或唯一key)
  completed: number;
  overdue: number;
}

export interface MonthlyStat {
  monthStr: string; // e.g., "2023-10"
  total: number;
  completed: number;
  overdue: number;
}

export interface WeeklyStat {
  weekLabel: string; // e.g., "第42周"
  completed: number;
}

// 检查是否同一天
function isSameDay(d1: Date, d2: Date): boolean {
  return d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate();
}

// 检查是否同一月
function isSameMonth(d1: Date, d2: Date): boolean {
  return d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth();
}

// 获取 ISO 周号 (简化版)
function getWeekNumber(d: Date): number {
  const date = new Date(d.getTime());
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7);
  const week1 = new Date(date.getFullYear(), 0, 4);
  return 1 + Math.round(((date.getTime() - week1.getTime()) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7);
}

// --- 3. 核心统计逻辑 (移植自 Android) ---

/**
 * 计算过去 days 天的每日完成和逾期情况
 */
export function computeDailyCompletedCounts(items: DDLItem[], days: number = 7): DailyStat[] {
  const result: DailyStat[] = [];
  const today = new Date();

  // 预处理数据：只处理已完成的任务
  const completedTasks = items.filter(it => it.isCompleted && it.completeTime);

  for (let i = days - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setDate(today.getDate() - i);

    // 1. 当天完成数
    const completedCount = completedTasks.filter(it => {
      const doneDate = safeParseDate(it.completeTime);
      return isSameDay(doneDate, targetDate);
    }).length;

    // 2. 当天逾期完成数 (完成时间 > 截止时间 且 完成时间是当天)
    const overdueCount = completedTasks.filter(it => {
      const doneDate = safeParseDate(it.completeTime);
      const endDate = safeParseDate(it.endTime);

      // 必须是当天完成
      if (!isSameDay(doneDate, targetDate)) return false;
      // 必须实际逾期 (完成时间 晚于 截止时间)
      return doneDate.getTime() > endDate.getTime();
    }).length;

    result.push({
      dateStr: targetDate.getDate().toString(), // UI只显示日期 "12"
      fullDate: targetDate.toDateString(),
      completed: completedCount,
      overdue: overdueCount
    });
  }
  return result;
}

/**
 * 计算过去 months 个月的任务趋势
 */
export function computeMonthlyTaskStats(items: DDLItem[], months: number = 6): MonthlyStat[] {
  const result: MonthlyStat[] = [];
  const today = new Date();

  for (let i = months - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setMonth(today.getMonth() - i); // 倒推月份

    const year = targetDate.getFullYear();
    const month = targetDate.getMonth() + 1; // 1-12
    const monthStr = `${year}-${month.toString().padStart(2, '0')}`;

    // 1. 当月任务总数 (截止日期在当月)
    const total = items.filter(it => {
      const endDate = safeParseDate(it.endTime);
      return isSameMonth(endDate, targetDate);
    }).length;

    // 2. 当月完成数 (完成日期在当月)
    const completed = items.filter(it => {
      if (!it.isCompleted || !it.completeTime) return false;
      const doneDate = safeParseDate(it.completeTime);
      return isSameMonth(doneDate, targetDate);
    }).length;

    // 3. 当月逾期完成数 (完成日期在当月 且 完成时间 > 截止时间)
    const overdue = items.filter(it => {
      if (!it.isCompleted || !it.completeTime) return false;
      const doneDate = safeParseDate(it.completeTime);
      const endDate = safeParseDate(it.endTime);

      return isSameMonth(doneDate, targetDate) && (doneDate.getTime() > endDate.getTime());
    }).length;

    result.push({
      monthStr: monthStr,
      total: total,
      completed: completed,
      overdue: overdue
    });
  }
  return result;
}

/**
 * 计算过去 weeks 周的完成数
 */
export function computeWeeklyCompletedCounts(items: DDLItem[], weeks: number = 4): WeeklyStat[] {
  const result: WeeklyStat[] = [];
  const today = new Date();

  // 简单起见，按 ISO 周号统计不太直观，我们这里模拟安卓逻辑：
  // 倒推周数，每周作为一个 bucket

  for (let i = weeks - 1; i >= 0; i--) {
    const targetDate = new Date(today);
    targetDate.setDate(today.getDate() - (i * 7)); // 每一周的基准点
    const weekNum = getWeekNumber(targetDate);
    const label = `第${weekNum}周`;

    // 筛选这一周内的完成数据 (注意：跨年周可能需要更严谨的判断，这里简化处理)
    // 更好的方式是判断日期是否在 [StartOfWeek, EndOfWeek] 区间
    // 这里为了性能，我们假设 "第X周" 的统计是聚合该周号的所有数据 (同年)

    const year = targetDate.getFullYear();

    const count = items.filter(it => {
      if (!it.isCompleted || !it.completeTime) return false;
      const doneDate = safeParseDate(it.completeTime);
      return doneDate.getFullYear() === year && getWeekNumber(doneDate) === weekNum;
    }).length;

    result.push({
      weekLabel: label,
      completed: count
    });
  }
  return result;
}

// --- 4. Dashboard 统计逻辑 (移植自 Android) ---

export interface Metric {
  label: string;
  value: string;
  change?: string;     // 变化量文本 (e.g., "12", "5%")
  isDown?: boolean;    // true=下降(红色), false=上升(绿色), null=持平(蓝色/无色)
}

interface MonthStats {
  total: number;
  completed: number;
  overdue: number;
  avgCompletionTimeMs: number; // 平均完成耗时 (毫秒)
}

// 获取上个月的起始和结束时间
export function getLastMonthRange(): [Date, Date] {
  const now = new Date();
  // 设为本月1号
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  // 设为本月0号 (即上个月最后一天) 23:59:59
  const end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
  return [start, end];
}

// 获取前上个月 (上上个月) 的起始和结束时间
export function getPrevMonthRange(): [Date, Date] {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - 2, 1);
  const end = new Date(now.getFullYear(), now.getMonth() - 1, 0, 23, 59, 59);
  return [start, end];
}

// 统计特定时间段的数据
function collectStatsInRange(items: DDLItem[], start: Date, end: Date): MonthStats {
  const filtered = items.filter(item => {
    if (!item.completeTime) return false;
    const ct = safeParseDate(item.completeTime);
    return ct >= start && ct <= end;
  });

  const total = filtered.length;
  const completed = filtered.filter(it => it.isCompleted).length;
  // 这里 isOverdue 需要 item, 我们复用之前的函数
  const overdue = filtered.filter(it => isOverdue(it)).length;

  let totalDuration = 0;
  let countWithDuration = 0;

  filtered.forEach(item => {
    if (item.startTime && item.completeTime) {
      const st = safeParseDate(item.startTime);
      const ct = safeParseDate(item.completeTime);
      const diff = ct.getTime() - st.getTime();
      if (diff > 0) {
        totalDuration += diff;
        countWithDuration++;
      }
    }
  });

  const avg = countWithDuration > 0 ? totalDuration / countWithDuration : 0;

  return { total, completed, overdue, avgCompletionTimeMs: avg };
}

// 计算数值变化
function computeChange(current: number, previous: number): [string | undefined, boolean | undefined] {
  if (previous === 0) {
    return current > 0 ? ["", undefined] : [undefined, undefined];
  }
  const diff = current - previous;
  if (diff === 0) return [undefined, undefined];

  const isDown = diff < 0;
  return [Math.abs(diff).toString(), isDown];
}

// 格式化百分比
function formatRate(part: number, total: number): string {
  return total > 0 ? Math.round((part * 100) / total) + "%" : "--";
}

// 计算百分比变化
function formatRateChange(
  part: number, total: number,
  prevPart: number, prevTotal: number
): [string | undefined, boolean | undefined] {
  if (total === 0 || prevTotal === 0) return [undefined, undefined];

  const rateNow = Math.round((part * 100) / total);
  const ratePrev = Math.round((prevPart * 100) / prevTotal);
  const diff = rateNow - ratePrev;

  if (diff === 0) return ["", undefined];
  const isDown = diff < 0;
  return [Math.abs(diff) + "%", isDown];
}

// 格式化时长 (毫秒 -> 天/小时)
function formatDuration(ms: number): string {
  const hours = Math.floor(ms / (1000 * 60 * 60));
  const days = Math.floor(hours / 24);
  const remainHours = hours % 24;

  if (days > 0) return `${days}天 ${remainHours}小时`;
  if (hours > 0) return `${hours}小时`;
  return "小于1小时";
}

// --- 核心入口：生成 Dashboard 指标列表 ---
export function generateDashboardMetrics(items: DDLItem[]): Metric[] {
  const lastMonthRange = getLastMonthRange();
  const lastStart = lastMonthRange[0];
  const lastEnd = lastMonthRange[1];
  const prevMonthRange = getPrevMonthRange();
  const prevStart = prevMonthRange[0];
  const prevEnd = prevMonthRange[1];

  const lastStats = collectStatsInRange(items, lastStart, lastEnd);
  const prevStats = collectStatsInRange(items, prevStart, prevEnd);

  // 1. 月份标题
  const monthName = `${lastStart.getFullYear()}年${lastStart.getMonth() + 1}月`;

  // 2. 各项指标
  const GeneratedDestructArray_1 = computeChange(lastStats.total, prevStats.total);
  const totalChange = GeneratedDestructArray_1[0];
  const totalDown = GeneratedDestructArray_1[1];
  const GeneratedDestructArray_2 = computeChange(lastStats.completed, prevStats.completed);
  const completedChange = GeneratedDestructArray_2[0];
  const completedDown = GeneratedDestructArray_2[1];
  const GeneratedDestructArray_3 = computeChange(lastStats.overdue, prevStats.overdue);
  const overdueChange = GeneratedDestructArray_3[0];
  const overdueDown = GeneratedDestructArray_3[1];

  const GeneratedDestructArray_4 = formatRateChange(
    lastStats.completed, lastStats.total,
    prevStats.completed, prevStats.total
  );
  const rateChange = GeneratedDestructArray_4[0];
  const rateDown = GeneratedDestructArray_4[1];
  const GeneratedDestructArray_5 = formatRateChange(
    lastStats.overdue, lastStats.total,
    prevStats.overdue, prevStats.total
  );
  const overdueRateChange = GeneratedDestructArray_5[0];
  const overdueRateDown = GeneratedDestructArray_5[1];

  return [
    { label: "统计月份", value: monthName },
    {
      label: "总任务数", value: lastStats.total.toString(),
      change: totalChange, isDown: totalDown
    },
    {
      label: "完成数", value: lastStats.completed.toString(),
      change: completedChange, isDown: completedDown
    },
    {
      label: "逾期数", value: lastStats.overdue.toString(),
      change: overdueChange, isDown: overdueDown
    },
    {
      label: "完成率", value: formatRate(lastStats.completed, lastStats.total),
      change: rateChange, isDown: rateDown
    },
    {
      label: "逾期率", value: formatRate(lastStats.overdue, lastStats.total),
      change: overdueRateChange, isDown: overdueRateDown
    },
    {
      label: "平均耗时", value: formatDuration(lastStats.avgCompletionTimeMs)
    }
  ];
}