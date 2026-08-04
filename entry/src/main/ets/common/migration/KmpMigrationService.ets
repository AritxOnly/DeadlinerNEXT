import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { KmpPersistenceService } from '../kmp/KmpPersistenceService';
import { LegacyRdbSnapshotExporter } from './LegacyRdbSnapshotExporter';
import { KmpMigrationValidator } from './KmpMigrationValidation';
import { KmpTaskRepositoryAdapter, LegacySubtaskIdentifier, LegacyTaskIdentifier } from '../kmp/KmpTaskRepositoryAdapter';
import { KmpHabitRepositoryAdapter, LegacyHabitIdentifier } from '../kmp/KmpHabitRepositoryAdapter';
import { KmpCaptureRepositoryAdapter } from '../kmp/KmpCaptureRepositoryAdapter';
import { DatabaseHelper } from '../data/DatabaseHelper';
import { LegacyMemoryProfileMigration } from './LegacyMemoryProfileMigration';
import { DDLItem, Habit, SubTask } from '../../model/DDLModels';

export enum KmpMigrationStatus {
  PENDING = 'pending',
  IMPORTING = 'importing',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

export class KmpMigrationState {
  public readonly status: KmpMigrationStatus;
  public readonly taskItemCount: number;
  public readonly habitItemCount: number;
  public readonly appliedItemCount: number;
  public readonly completedAt: string;

  constructor(status: KmpMigrationStatus, taskItemCount: number, habitItemCount: number, appliedItemCount: number, completedAt: string) {
    this.status = status;
    this.taskItemCount = taskItemCount;
    this.habitItemCount = habitItemCount;
    this.appliedItemCount = appliedItemCount;
    this.completedAt = completedAt;
  }
}

class KmpMigrationStateStore {
  private static readonly PREFERENCE_NAME: string = 'kmp_migration_state';
  private static readonly STATUS_KEY: string = 'legacy_rdb_v2_status';
  private static readonly TASK_COUNT_KEY: string = 'legacy_rdb_v2_task_count';
  private static readonly HABIT_COUNT_KEY: string = 'legacy_rdb_v2_habit_count';
  private static readonly APPLIED_COUNT_KEY: string = 'legacy_rdb_v2_applied_count';
  private static readonly COMPLETED_AT_KEY: string = 'legacy_rdb_v2_completed_at';
  private static readonly COMPATIBILITY_COMPLETED_KEY: string = 'legacy_rdb_v2_compatibility_completed';

  public async load(context: common.Context): Promise<KmpMigrationState> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationStateStore.PREFERENCE_NAME);
    const statusValue = await store.get(KmpMigrationStateStore.STATUS_KEY, KmpMigrationStatus.PENDING);
    const taskCountValue = await store.get(KmpMigrationStateStore.TASK_COUNT_KEY, 0);
    const habitCountValue = await store.get(KmpMigrationStateStore.HABIT_COUNT_KEY, 0);
    const appliedCountValue = await store.get(KmpMigrationStateStore.APPLIED_COUNT_KEY, 0);
    const completedAtValue = await store.get(KmpMigrationStateStore.COMPLETED_AT_KEY, '');
    return new KmpMigrationState(
      this.readStatus(statusValue),
      this.readNumber(taskCountValue),
      this.readNumber(habitCountValue),
      this.readNumber(appliedCountValue),
      this.readString(completedAtValue)
    );
  }

  public async save(context: common.Context, state: KmpMigrationState): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationStateStore.PREFERENCE_NAME);
    await store.put(KmpMigrationStateStore.STATUS_KEY, state.status);
    await store.put(KmpMigrationStateStore.TASK_COUNT_KEY, state.taskItemCount);
    await store.put(KmpMigrationStateStore.HABIT_COUNT_KEY, state.habitItemCount);
    await store.put(KmpMigrationStateStore.APPLIED_COUNT_KEY, state.appliedItemCount);
    await store.put(KmpMigrationStateStore.COMPLETED_AT_KEY, state.completedAt);
    await store.flush();
  }

  public async isCompatibilityMigrationCompleted(context: common.Context): Promise<boolean> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationStateStore.PREFERENCE_NAME);
    const value: preferences.ValueType = await store.get(KmpMigrationStateStore.COMPATIBILITY_COMPLETED_KEY, false);
    return value === true;
  }

  public async markCompatibilityMigrationCompleted(context: common.Context): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationStateStore.PREFERENCE_NAME);
    await store.put(KmpMigrationStateStore.COMPATIBILITY_COMPLETED_KEY, true);
    await store.flush();
  }

  private readStatus(value: preferences.ValueType): KmpMigrationStatus {
    if (value === KmpMigrationStatus.IMPORTING) return KmpMigrationStatus.IMPORTING;
    if (value === KmpMigrationStatus.COMPLETED) return KmpMigrationStatus.COMPLETED;
    if (value === KmpMigrationStatus.FAILED) return KmpMigrationStatus.FAILED;
    return KmpMigrationStatus.PENDING;
  }

  private readNumber(value: preferences.ValueType): number {
    return typeof value === 'number' ? value : 0;
  }

  private readString(value: preferences.ValueType): string {
    return typeof value === 'string' ? value : '';
  }
}

/** Coordinates the one-time, repeat-safe import while legacy RDB remains the production source. */
export class KmpMigrationService {
  private static instance: KmpMigrationService;
  private migrationPromise: Promise<KmpMigrationState> | null = null;
  private readonly stateStore: KmpMigrationStateStore = new KmpMigrationStateStore();
  private readonly exporter: LegacyRdbSnapshotExporter = new LegacyRdbSnapshotExporter();
  private readonly validator: KmpMigrationValidator = KmpMigrationValidator.getInstance();
  private readonly taskCompatibility: KmpTaskRepositoryAdapter = new KmpTaskRepositoryAdapter();
  private readonly habitCompatibility: KmpHabitRepositoryAdapter = new KmpHabitRepositoryAdapter(this.taskCompatibility);
  private readonly captureCompatibility: KmpCaptureRepositoryAdapter = new KmpCaptureRepositoryAdapter();
  private readonly memoryProfileMigration: LegacyMemoryProfileMigration = new LegacyMemoryProfileMigration();

  public static getInstance(): KmpMigrationService {
    if (!KmpMigrationService.instance) {
      KmpMigrationService.instance = new KmpMigrationService();
    }
    return KmpMigrationService.instance;
  }

  /** EntryAbility uses this to open the legacy RDB only while a one-time import is still needed. */
  public async requiresLegacyRdbMigration(context: common.Context): Promise<boolean> {
    const state: KmpMigrationState = await this.stateStore.load(context);
    if (state.status !== KmpMigrationStatus.COMPLETED) return true;
    return !await this.stateStore.isCompatibilityMigrationCompleted(context);
  }

  /** Starts exactly one migration transaction and exposes it as the application data-readiness gate. */
  public start(context: common.Context): Promise<KmpMigrationState> {
    if (this.migrationPromise === null) this.migrationPromise = this.runMigration(context);
    return this.migrationPromise;
  }

  public async awaitReady(): Promise<void> {
    if (this.migrationPromise === null) throw new Error('KMP migration startup has not begun');
    await this.migrationPromise;
  }

  private async runMigration(context: common.Context): Promise<KmpMigrationState> {
    await KmpPersistenceService.getInstance().initialize(context);
    if (await this.requiresLegacyRdbMigration(context)) {
      await DatabaseHelper.getInstance().init(context);
    }
    const previous: KmpMigrationState = await this.stateStore.load(context);
    if (previous.status === KmpMigrationStatus.COMPLETED) {
      await this.migrateLegacyCompatibilityIfNeeded(context);
      await this.memoryProfileMigration.migrateIfNeeded(context);
      await this.validator.validate(
        context,
        previous.taskItemCount,
        previous.habitItemCount,
        previous.appliedItemCount
      );
      return previous;
    }

    const importing: KmpMigrationState = new KmpMigrationState(KmpMigrationStatus.IMPORTING, 0, 0, 0, '');
    await this.stateStore.save(context, importing);
    try {
      const snapshot = await this.exporter.exportSnapshot();
      const appliedItemCount: number = KmpPersistenceService.getInstance().importLegacyV2(
        snapshot.taskPayload,
        snapshot.habitPayload
      );
      const completed: KmpMigrationState = new KmpMigrationState(
        KmpMigrationStatus.COMPLETED,
        snapshot.taskItemCount,
        snapshot.habitItemCount,
        appliedItemCount,
        new Date().toISOString()
      );
      const report = await this.validator.validate(
        context,
        completed.taskItemCount,
        completed.habitItemCount,
        completed.appliedItemCount
      );
      if (!report.isValid) {
        const failed: KmpMigrationState = new KmpMigrationState(
          KmpMigrationStatus.FAILED,
          completed.taskItemCount,
          completed.habitItemCount,
          completed.appliedItemCount,
          ''
        );
        await this.stateStore.save(context, failed);
        throw new Error('KMP persistence migration validation failed');
      }
      await this.migrateLegacyCompatibilityIfNeeded(context);
      await this.memoryProfileMigration.migrateIfNeeded(context);
      await this.stateStore.save(context, completed);
      return completed;
    } catch (err) {
      const failed: KmpMigrationState = new KmpMigrationState(KmpMigrationStatus.FAILED, 0, 0, 0, '');
      await this.stateStore.save(context, failed);
      throw new Error('KMP persistence migration failed: ' + String(err));
    }
  }

  /** Keeps all ArkData reads inside a durable, one-time compatibility checkpoint. */
  private async migrateLegacyCompatibilityIfNeeded(context: common.Context): Promise<void> {
    if (await this.stateStore.isCompatibilityMigrationCompleted(context)) return;
    const database: DatabaseHelper = DatabaseHelper.getInstance();
    const taskIdentifiers: LegacyTaskIdentifier[] = await this.loadLegacyTaskIdentifiers(database);
    const habitIdentifiers: LegacyHabitIdentifier[] = await this.loadLegacyHabitIdentifiers(database);
    await this.taskCompatibility.importLegacyNumericIds(context, taskIdentifiers);
    await this.habitCompatibility.importLegacyNumericIds(context, habitIdentifiers);
    await this.captureCompatibility.importLegacy(context, await database.getAllInspirations());
    await this.validateCaptureCount();
    await this.stateStore.markCompatibilityMigrationCompleted(context);
  }

  private async loadLegacyTaskIdentifiers(database: DatabaseHelper): Promise<LegacyTaskIdentifier[]> {
    const legacyItems: DDLItem[] = await database.getAllDDLs();
    const identifiers: LegacyTaskIdentifier[] = [];
    for (let itemIndex = 0; itemIndex < legacyItems.length; itemIndex++) {
      const item: DDLItem = legacyItems[itemIndex];
      if (item.uid === undefined || item.uid.length === 0) continue;
      const legacySubtasks: SubTask[] = await database.getSubTasksByDDL(item.id);
      const subtasks: LegacySubtaskIdentifier[] = [];
      for (let subtaskIndex = 0; subtaskIndex < legacySubtasks.length; subtaskIndex++) {
        const subtask: SubTask = legacySubtasks[subtaskIndex];
        if (subtask.uid !== undefined && subtask.uid.length > 0) {
          subtasks.push({ uid: subtask.uid, id: subtask.id });
        }
      }
      identifiers.push({ uid: item.uid, id: item.id, type: item.type, subtasks: subtasks });
    }
    return identifiers;
  }

  private async loadLegacyHabitIdentifiers(database: DatabaseHelper): Promise<LegacyHabitIdentifier[]> {
    const habits: Habit[] = await database.getAllHabits();
    const identifiers: LegacyHabitIdentifier[] = [];
    for (let index = 0; index < habits.length; index++) {
      const habit: Habit = habits[index];
      const ddl: DDLItem | null = await database.getDDLById(habit.ddlId);
      if (ddl !== null && ddl.uid !== undefined && ddl.uid.length > 0) {
        identifiers.push({ habitId: habit.id, taskUid: ddl.uid });
      }
    }
    return identifiers;
  }

  private async validateCaptureCount(): Promise<void> {
    const legacyCount: number = (await DatabaseHelper.getInstance().getAllInspirations()).length;
    const diagnostics: string = KmpPersistenceService.getInstance().diagnosticsJson();
    const prefix: string = '"captures":';
    const start: number = diagnostics.indexOf(prefix);
    if (start < 0) throw new Error('KMP capture diagnostics unavailable');
    let cursor: number = start + prefix.length;
    let digits: string = '';
    while (cursor < diagnostics.length && diagnostics.charAt(cursor) >= '0' && diagnostics.charAt(cursor) <= '9') {
      digits += diagnostics.charAt(cursor); cursor++;
    }
    if (Number(digits) !== legacyCount) throw new Error('KMP capture migration validation failed');
  }
}
