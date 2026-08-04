import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { KmpPersistenceService } from '../kmp/KmpPersistenceService';

interface LegacyMemoryFragment {
  id: string;
  content: string;
  category: string;
  timestamp: number;
  importance: number;
}

interface KmpMemoryPayload {
  uid: string;
  content: string;
  category: string;
  createdAt: string;
  importance: number;
  updatedAt: string;
  isDeleted: boolean;
}

interface KmpProfilePayload {
  uid: string;
  nickname: string;
  avatarFileName: string | null;
  tier: string;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

interface KmpMemoryProfilePayload {
  fragments: KmpMemoryPayload[];
  profiles: KmpProfilePayload[];
}

/** Reads legacy Preferences exactly once; no business repository uses this class. */
export class LegacyMemoryProfileMigration {
  private static readonly PREFERENCE_NAME: string = 'deadliner_memory_store';
  private static readonly FRAGMENTS_KEY: string = 'deadliner_local_memories';
  private static readonly PROFILE_KEY: string = 'deadliner_user_profile';
  private static readonly STATE_NAME: string = 'kmp_memory_profile_migration';
  private static readonly COMPLETED_KEY: string = 'completed';

  public async migrateIfNeeded(context: common.Context): Promise<void> {
    const state: preferences.Preferences = await preferences.getPreferences(context, LegacyMemoryProfileMigration.STATE_NAME);
    const completed: preferences.ValueType = await state.get(LegacyMemoryProfileMigration.COMPLETED_KEY, false);
    if (completed === true) return;
    const legacy: preferences.Preferences = await preferences.getPreferences(context, LegacyMemoryProfileMigration.PREFERENCE_NAME);
    const encoded: preferences.ValueType = await legacy.get(LegacyMemoryProfileMigration.FRAGMENTS_KEY, '');
    const profileValue: preferences.ValueType = await legacy.get(LegacyMemoryProfileMigration.PROFILE_KEY, '');
    const fragments: LegacyMemoryFragment[] = this.readFragments(encoded);
    const now: string = new Date().toISOString();
    const payload: KmpMemoryProfilePayload = { fragments: [], profiles: [] };
    for (let index = 0; index < fragments.length; index++) {
      const fragment: LegacyMemoryFragment = fragments[index];
      const createdAt: string = new Date(fragment.timestamp).toISOString();
      payload.fragments.push({ uid: fragment.id, content: fragment.content, category: fragment.category, createdAt: createdAt, importance: fragment.importance, updatedAt: createdAt, isDeleted: false });
    }
    if (typeof profileValue === 'string' && profileValue.length > 0) {
      payload.profiles.push({ uid: 'legacy-ohos-memory-profile', nickname: profileValue, avatarFileName: null, tier: 'FREE', createdAt: now, updatedAt: now, isDeleted: false });
    }
    KmpPersistenceService.getInstance().importMemoryProfileJson(JSON.stringify(payload));
    this.verifyImportedCount(payload);
    await state.put(LegacyMemoryProfileMigration.COMPLETED_KEY, true);
    await state.flush();
  }

  private readFragments(value: preferences.ValueType): LegacyMemoryFragment[] {
    if (typeof value !== 'string' || value.length === 0) return [];
    try {
      return JSON.parse(value) as LegacyMemoryFragment[];
    } catch (_) {
      throw new Error('Legacy memory Preferences contains invalid JSON');
    }
  }

  private verifyImportedCount(payload: KmpMemoryProfilePayload): void {
    const diagnostics: string = KmpPersistenceService.getInstance().diagnosticsJson();
    const fragmentCount: number = this.readDiagnosticCount(diagnostics, 'memory_fragments');
    const profileCount: number = this.readDiagnosticCount(diagnostics, 'user_profiles');
    if (fragmentCount < payload.fragments.length || profileCount < payload.profiles.length) {
      throw new Error('KMP memory/profile migration validation failed');
    }
  }

  private readDiagnosticCount(diagnostics: string, key: string): number {
    const prefix: string = '"' + key + '":';
    const start: number = diagnostics.indexOf(prefix);
    if (start < 0) throw new Error('KMP memory/profile diagnostics unavailable');
    let cursor: number = start + prefix.length;
    let digits: string = '';
    while (cursor < diagnostics.length && diagnostics.charAt(cursor) >= '0' && diagnostics.charAt(cursor) <= '9') {
      digits += diagnostics.charAt(cursor);
      cursor++;
    }
    return Number(digits);
  }
}
