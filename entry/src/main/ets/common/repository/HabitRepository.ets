import { DatabaseHelper } from '../data/DatabaseHelper';
import {
  Habit, HabitPeriod, HabitGoalType, HabitRecord, HabitRecordStatus, HabitStatus
} from '../../model/DDLModels'; // 假设你的路径

export class HabitRepository {
  private static instance: HabitRepository;
  private db: DatabaseHelper;

  private constructor() {
    this.db = DatabaseHelper.getInstance();
  }

  public static getInstance(): HabitRepository {
    if (!HabitRepository.instance) {
      HabitRepository.instance = new HabitRepository();
    }
    return HabitRepository.instance;
  }

  // ================= Helper: Date Formatting =================
  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  private nowISO(): string {
    return new Date().toISOString();
  }

  // ================= Habit 本体 =================

  async createHabitForDdl(
    ddlId: number,
    name: string,
    period: HabitPeriod,
    timesPerPeriod: number = 1,
    goalType: HabitGoalType = HabitGoalType.PER_PERIOD,
    totalTarget: number | null = null,
    description: string = "",
    color: number | null = null,
    iconKey: string | null = null,
    sortOrder: number = 0,
    alarmTime: string | null = null
  ): Promise<number> {
    const now = this.nowISO();
    const habit: Habit = {
      id: 0, // Auto-increment handled by DB
      ddlId: ddlId,
      name: name,
      description: description,
      color: color,
      iconKey: iconKey,
      period: period,
      timesPerPeriod: timesPerPeriod,
      goalType: goalType,
      totalTarget: totalTarget,
      createdAt: now,
      updatedAt: now,
      status: HabitStatus.ACTIVE,
      sortOrder: sortOrder,
      alarmTime: alarmTime
    };
    return await this.db.insertHabit(habit);
  }

  async getHabitByDdlId(ddlId: number): Promise<Habit | null> {
    return await this.db.getHabitByDdlId(ddlId);
  }

  async getHabitById(id: number): Promise<Habit | null> {
    return await this.db.getHabitById(id);
  }

  async getAllHabits(): Promise<Habit[]> {
    return await this.db.getAllHabits();
  }

  async updateHabit(habit: Habit): Promise<void> {
    const now = this.nowISO();

    const updated: Habit = {
      id: habit.id,
      ddlId: habit.ddlId,
      name: habit.name,
      description: habit.description,
      color: habit.color,
      iconKey: habit.iconKey,
      period: habit.period,
      timesPerPeriod: habit.timesPerPeriod,
      goalType: habit.goalType,
      totalTarget: habit.totalTarget,
      createdAt: habit.createdAt,
      updatedAt: now,
      status: habit.status,
      sortOrder: habit.sortOrder,
      alarmTime: habit.alarmTime
    };

    await this.db.updateHabit(updated);
  }

  async deleteHabitByDdlId(ddlId: number): Promise<void> {
    await this.db.deleteHabitByDdlId(ddlId);
  }

  // ================= Habit 打卡记录 =================

  async getRecordsForHabitOnDate(habitId: number, date: Date): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
  }

  async getRecordsForDate(date: Date): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForDate(this.formatDate(date));
  }

  async getRecordsForHabitInRange(
    habitId: number,
    startDate: Date,
    endDateInclusive: Date
  ): Promise<HabitRecord[]> {
    return await this.db.getHabitRecordsForHabitInRange(
      habitId,
      this.formatDate(startDate),
      this.formatDate(endDateInclusive)
    );
  }

  async insertRecord(
    habitId: number,
    date: Date,
    count: number = 1,
    status: HabitRecordStatus = HabitRecordStatus.COMPLETED
  ): Promise<number> {
    const record: HabitRecord = {
      id: 0,
      habitId: habitId,
      date: this.formatDate(date),
      count: count,
      status: status,
      createdAt: this.nowISO()
    };
    return await this.db.insertHabitRecord(record);
  }

  async deleteRecordsForHabitOnDate(habitId: number, date: Date): Promise<void> {
    await this.db.deleteHabitRecordsForHabitOnDate(habitId, this.formatDate(date));
  }

  async getCompletedIdsForDate(date: Date): Promise<Set<number>> {
    const records = await this.getRecordsForDate(date);
    const set = new Set<number>();
    records.forEach(r => {
      if (r.status === HabitRecordStatus.COMPLETED) {
        set.add(r.habitId);
      }
    });
    return set;
  }

  // ================= Logic: Period Calculation =================

  private periodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const d = new Date(date); // Clone
    d.setHours(0, 0, 0, 0);

    if (period === HabitPeriod.DAILY) {
      return [d, d];
    } else if (period === HabitPeriod.WEEKLY) {
      // Find Monday. getDay(): 0 is Sunday, 1 is Monday...
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
      const monday = new Date(d.setDate(diff));

      const sunday = new Date(monday);
      sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    } else if (period === HabitPeriod.MONTHLY) {
      const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return [firstDay, lastDay];
    }
    return [d, d];
  }

  // ================= Logic: Toggle =================

  /**
   * 切换某天某个习惯的完成状态
   */
  async toggleRecord(habitId: number, date: Date): Promise<void> {
    const habit = await this.getHabitById(habitId);
    if (!habit) return;

    const target = Math.max(1, habit.timesPerPeriod);

    if (habit.period === HabitPeriod.DAILY) {
      // —— 每日习惯 ——
      const recordsToday = (await this.getRecordsForHabitOnDate(habitId, date))
        .filter(r => r.status === HabitRecordStatus.COMPLETED);

      const currentCount = recordsToday.reduce((sum, r) => sum + r.count, 0);

      if (currentCount <= 0) {
        // 0 -> 1
        await this.insertRecord(habitId, date, 1, HabitRecordStatus.COMPLETED);
      } else if (currentCount < target) {
        // 1..target-1 -> +1
        await this.insertRecord(habitId, date, 1, HabitRecordStatus.COMPLETED);
      } else {
        // 已达标 -> 清空
        await this.deleteRecordsForHabitOnDate(habitId, date);
      }

    } else {
      // —— 周/月习惯 ——
      const periodBounds = this.periodBounds(habit.period, date);
      const start = periodBounds[0];
      const endInclusive = periodBounds[1];

      const recordsInPeriod = (await this.getRecordsForHabitInRange(habitId, start, endInclusive))
        .filter(r => r.status === HabitRecordStatus.COMPLETED);

      const totalInPeriod = recordsInPeriod.reduce((sum, r) => sum + r.count, 0);

      // Check records strictly on *this* date
      const dateStr = this.formatDate(date);
      const recordsToday = recordsInPeriod.filter(r => r.date === dateStr);
      const todayCount = recordsToday.reduce((sum, r) => sum + r.count, 0);

      if (todayCount > 0) {
        // 今天有记录 -> 取消今天
        await this.deleteRecordsForHabitOnDate(habitId, date);
      } else if (totalInPeriod >= target) {
        // 周期已满 -> 无操作
        // no-op
      } else {
        // 周期未满，且今天没打 -> 打卡
        await this.insertRecord(habitId, date, 1, HabitRecordStatus.COMPLETED);
      }
    }
  }
}