import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { KmpPersistenceService } from '../kmp/KmpPersistenceService';

export class KmpMigrationValidationReport {
  public readonly bridgeVersion: number;
  public readonly bridgeReady: boolean;
  public readonly legacyTaskItemCount: number;
  public readonly legacyHabitItemCount: number;
  public readonly kmpTaskItemCount: number;
  public readonly kmpHabitItemCount: number;
  public readonly appliedItemCount: number;
  public readonly isValid: boolean;
  public readonly validatedAt: string;

  constructor(
    bridgeVersion: number,
    bridgeReady: boolean,
    legacyTaskItemCount: number,
    legacyHabitItemCount: number,
    kmpTaskItemCount: number,
    kmpHabitItemCount: number,
    appliedItemCount: number,
    isValid: boolean,
    validatedAt: string
  ) {
    this.bridgeVersion = bridgeVersion;
    this.bridgeReady = bridgeReady;
    this.legacyTaskItemCount = legacyTaskItemCount;
    this.legacyHabitItemCount = legacyHabitItemCount;
    this.kmpTaskItemCount = kmpTaskItemCount;
    this.kmpHabitItemCount = kmpHabitItemCount;
    this.appliedItemCount = appliedItemCount;
    this.isValid = isValid;
    this.validatedAt = validatedAt;
  }
}

class KmpMigrationValidationStore {
  private static readonly PREFERENCE_NAME: string = 'kmp_migration_validation';
  private static readonly BRIDGE_VERSION_KEY: string = 'bridge_version';
  private static readonly BRIDGE_READY_KEY: string = 'bridge_ready';
  private static readonly LEGACY_TASK_COUNT_KEY: string = 'legacy_task_count';
  private static readonly LEGACY_HABIT_COUNT_KEY: string = 'legacy_habit_count';
  private static readonly KMP_TASK_COUNT_KEY: string = 'kmp_task_count';
  private static readonly KMP_HABIT_COUNT_KEY: string = 'kmp_habit_count';
  private static readonly APPLIED_COUNT_KEY: string = 'applied_count';
  private static readonly VALID_KEY: string = 'is_valid';
  private static readonly VALIDATED_AT_KEY: string = 'validated_at';

  public async load(context: common.Context): Promise<KmpMigrationValidationReport> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationValidationStore.PREFERENCE_NAME);
    return new KmpMigrationValidationReport(
      this.readNumber(await store.get(KmpMigrationValidationStore.BRIDGE_VERSION_KEY, 0)),
      this.readBoolean(await store.get(KmpMigrationValidationStore.BRIDGE_READY_KEY, false)),
      this.readNumber(await store.get(KmpMigrationValidationStore.LEGACY_TASK_COUNT_KEY, 0)),
      this.readNumber(await store.get(KmpMigrationValidationStore.LEGACY_HABIT_COUNT_KEY, 0)),
      this.readNumber(await store.get(KmpMigrationValidationStore.KMP_TASK_COUNT_KEY, -1)),
      this.readNumber(await store.get(KmpMigrationValidationStore.KMP_HABIT_COUNT_KEY, -1)),
      this.readNumber(await store.get(KmpMigrationValidationStore.APPLIED_COUNT_KEY, -1)),
      this.readBoolean(await store.get(KmpMigrationValidationStore.VALID_KEY, false)),
      this.readString(await store.get(KmpMigrationValidationStore.VALIDATED_AT_KEY, ''))
    );
  }

  public async save(context: common.Context, report: KmpMigrationValidationReport): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(context, KmpMigrationValidationStore.PREFERENCE_NAME);
    await store.put(KmpMigrationValidationStore.BRIDGE_VERSION_KEY, report.bridgeVersion);
    await store.put(KmpMigrationValidationStore.BRIDGE_READY_KEY, report.bridgeReady);
    await store.put(KmpMigrationValidationStore.LEGACY_TASK_COUNT_KEY, report.legacyTaskItemCount);
    await store.put(KmpMigrationValidationStore.LEGACY_HABIT_COUNT_KEY, report.legacyHabitItemCount);
    await store.put(KmpMigrationValidationStore.KMP_TASK_COUNT_KEY, report.kmpTaskItemCount);
    await store.put(KmpMigrationValidationStore.KMP_HABIT_COUNT_KEY, report.kmpHabitItemCount);
    await store.put(KmpMigrationValidationStore.APPLIED_COUNT_KEY, report.appliedItemCount);
    await store.put(KmpMigrationValidationStore.VALID_KEY, report.isValid);
    await store.put(KmpMigrationValidationStore.VALIDATED_AT_KEY, report.validatedAt);
    await store.flush();
  }

  private readNumber(value: preferences.ValueType): number {
    return typeof value === 'number' ? value : 0;
  }

  private readBoolean(value: preferences.ValueType): boolean {
    return typeof value === 'boolean' ? value : false;
  }

  private readString(value: preferences.ValueType): string {
    return typeof value === 'string' ? value : '';
  }
}

/** Persists a conservative import report before a KMP domain may be enabled. */
export class KmpMigrationValidator {
  private static instance: KmpMigrationValidator;
  private readonly store: KmpMigrationValidationStore = new KmpMigrationValidationStore();

  public static getInstance(): KmpMigrationValidator {
    if (!KmpMigrationValidator.instance) {
      KmpMigrationValidator.instance = new KmpMigrationValidator();
    }
    return KmpMigrationValidator.instance;
  }

  public async validate(
    context: common.Context,
    legacyTaskItemCount: number,
    legacyHabitItemCount: number,
    appliedItemCount: number
  ): Promise<KmpMigrationValidationReport> {
    const persistence: KmpPersistenceService = KmpPersistenceService.getInstance();
    const bridgeReady: boolean = persistence.isReady();
    const bridgeVersion: number = bridgeReady ? persistence.bridgeVersion() : 0;
    const diagnostics: string = bridgeReady ? persistence.diagnosticsJson() : '';
    const kmpTaskItemCount: number = this.readDiagnosticCount(diagnostics, 'tasks');
    const kmpHabitItemCount: number = this.readDiagnosticCount(diagnostics, 'habits');
    const isValid: boolean = bridgeReady && bridgeVersion >= 4 && appliedItemCount >= 0 &&
      legacyTaskItemCount === kmpTaskItemCount && legacyHabitItemCount === kmpHabitItemCount;
    const report: KmpMigrationValidationReport = new KmpMigrationValidationReport(
      bridgeVersion,
      bridgeReady,
      legacyTaskItemCount,
      legacyHabitItemCount,
      kmpTaskItemCount,
      kmpHabitItemCount,
      appliedItemCount,
      isValid,
      new Date().toISOString()
    );
    await this.store.save(context, report);
    return report;
  }

  public async loadReport(context: common.Context): Promise<KmpMigrationValidationReport> {
    return this.store.load(context);
  }

  private readDiagnosticCount(payload: string, field: string): number {
    const fieldPrefix: string = '"' + field + '":';
    const fieldIndex: number = payload.indexOf(fieldPrefix);
    if (fieldIndex < 0) {
      return -1;
    }
    let cursor: number = fieldIndex + fieldPrefix.length;
    let digits: string = '';
    while (cursor < payload.length) {
      const character: string = payload.charAt(cursor);
      if (character < '0' || character > '9') {
        break;
      }
      digits += character;
      cursor++;
    }
    return digits.length > 0 ? Number(digits) : -1;
  }
}
