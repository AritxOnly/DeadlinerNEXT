import { HabitWithDailyStatus } from "../../components/HabitComponents";
import { TaskUIModel } from "../main/TaskListSection";

export enum TimelineItemType {
  TASK = 'TASK',
  HABIT = 'HABIT'
}

// 列表项：可能是任务，也可能是习惯
export interface TimelineItem {
  id: string;              // 用于 ForEach 的唯一键
  type: TimelineItemType;  // 类型
  sortTime: number;        // 用于排序的时间戳

  // 数据载体 (使用可选属性)
  taskData?: TaskUIModel;
  habitData?: HabitWithDailyStatus;
}

// 分组：例如 "今天", "明天"
export interface TimelineGroup {
  groupId: string;     // 唯一标识，例如 'today', 'overdue'
  title: string;       // 显示标题
  items: TimelineItem[];
}