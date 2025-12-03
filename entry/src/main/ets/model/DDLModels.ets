// 对应 Kotlin: DeadlineType
export enum DeadlineType {
  TASK = 'task',
  HABIT = 'habit'
}

// 对应 Kotlin: HabitPeriod
export enum HabitPeriod {
  DAILY = 'DAILY',
  WEEKLY = 'WEEKLY',
  MONTHLY = 'MONTHLY'
}

// 对应 Kotlin: HabitGoalType
export enum HabitGoalType {
  PER_PERIOD = 'PER_PERIOD',
  TOTAL = 'TOTAL'
}

// 对应 Kotlin: HabitStatus
export enum HabitStatus {
  ACTIVE = 'ACTIVE',
  ARCHIVED = 'ARCHIVED'
}

// 对应 Kotlin: HabitRecordStatus
export enum HabitRecordStatus {
  COMPLETED = 'COMPLETED',
  SKIPPED = 'SKIPPED', // 假设你有这个，虽然原代码只看到 COMPLETED
  FAILED = 'FAILED'
}

// 对应 Kotlin: DDLItem
export interface DDLItem {
  id: number; // Long -> number
  name: string;
  startTime: string;
  endTime: string;
  isCompleted: boolean;
  completeTime: string;
  note: string;
  isArchived: boolean;
  isStared: boolean;
  type: DeadlineType;
  habitCount: number;
  habitTotalCount: number;
  calendarEventId: number | null;
  timeStamp: string;

  // Sync fields
  uid?: string;
  deleted: boolean; // 0 or 1 in DB, boolean in model
  verTs: string;
  verCtr: number;
  verDev: string;
}

// 对应 Kotlin: Habit
export interface Habit {
  id: number;
  ddlId: number;
  name: string;
  description: string | null;
  color: number | null;
  iconKey: string | null;
  period: HabitPeriod;
  timesPerPeriod: number;
  goalType: HabitGoalType;
  totalTarget: number | null;
  createdAt: string;
  updatedAt: string;
  status: HabitStatus;
  sortOrder: number;
  alarmTime: string | null;
}

// 对应 Kotlin: HabitRecord
export interface HabitRecord {
  id: number;
  habitId: number;
  date: string; // LocalDate.toString() -> "YYYY-MM-DD"
  count: number;
  status: HabitRecordStatus;
  createdAt: string;
}

// 对应 Kotlin: Ver (用于同步)
export interface Ver {
  ts: string;
  ctr: number;
  dev: string;
}