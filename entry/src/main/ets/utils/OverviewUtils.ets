import { DDLItem } from '../model/DDLModels';

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
    if (hour >= 0 && hour < 6) return '深夜 (00-06)';
    if (hour >= 6 && hour < 12) return '上午 (06-12)';
    if (hour >= 12 && hour < 18) return '下午 (12-18)';
    if (hour >= 18 && hour <= 23) return '晚上 (18-24)';
    return '未知';
  } catch (e) {
    return '未知';
  }
}

// 时间段排序权重
export const bucketOrder: Record<string, number> = {
  '深夜 (00-06)': 0,
  '上午 (06-12)': 1,
  '下午 (12-18)': 2,
  '晚上 (18-24)': 3,
  '未知': 4
};