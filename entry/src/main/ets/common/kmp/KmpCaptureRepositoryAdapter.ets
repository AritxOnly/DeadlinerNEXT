import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { InspirationItem } from '../../model/InspirationModels';
import { KmpPersistenceService } from './KmpPersistenceService';

interface KmpCapturePayload {
  uid: string;
  text: string;
  source: string;
  createdAt: string;
  updatedAt: string;
  isConsumed: boolean;
  isDeleted: boolean;
}

interface KmpCaptureStatePayload {
  items: KmpCapturePayload[];
  viewModelItems: KmpCapturePayload[];
}

export class KmpCaptureRepositoryAdapter {
  private static readonly PREFERENCE_NAME: string = 'kmp_capture_compatibility';
  private static readonly ID_PREFIX: string = 'capture_uid:';
  private static readonly NEXT_ID_KEY: string = 'next_id';
  private store: preferences.Preferences | null = null;

  public async initialize(context: common.Context): Promise<void> {
    if (this.store === null) this.store = await preferences.getPreferences(context, KmpCaptureRepositoryAdapter.PREFERENCE_NAME);
  }

  public async importLegacy(context: common.Context, items: InspirationItem[]): Promise<number> {
    await this.initialize(context);
    const captures: KmpCapturePayload[] = [];
    for (let index = 0; index < items.length; index++) {
      const item: InspirationItem = items[index];
      const uid: string = 'legacy-ohos-capture:' + item.id.toString();
      await this.bindId(uid, item.id);
      captures.push({ uid: uid, text: item.text, source: 'MANUAL', createdAt: item.createdAt, updatedAt: item.updatedAt, isConsumed: false, isDeleted: false });
    }
    return KmpPersistenceService.getInstance().importCapturesJson(JSON.stringify(captures));
  }

  public async list(): Promise<InspirationItem[]> {
    const state: KmpCaptureStatePayload = this.readState(KmpPersistenceService.getInstance().captureStateJson());
    const result: InspirationItem[] = [];
    for (let index = 0; index < state.items.length; index++) {
      const item: KmpCapturePayload = state.items[index];
      if (!item.isDeleted) result.push(await this.toInspiration(item));
    }
    return result;
  }

  public async find(id: number): Promise<InspirationItem | null> {
    const items: InspirationItem[] = await this.list();
    for (let index = 0; index < items.length; index++) if (items[index].id === id) return items[index];
    return null;
  }

  public async create(text: string): Promise<number> {
    const now: string = new Date().toISOString();
    const item: KmpCapturePayload = { uid: util.generateRandomUUID(true), text: text, source: 'MANUAL', createdAt: now, updatedAt: now, isConsumed: false, isDeleted: false };
    KmpPersistenceService.getInstance().captureCreateJson(JSON.stringify(item));
    return this.idFor(item.uid);
  }

  public async update(item: InspirationItem): Promise<void> {
    const current: KmpCapturePayload = await this.requireRaw(item.id);
    current.text = item.text;
    current.updatedAt = new Date().toISOString();
    KmpPersistenceService.getInstance().captureUpdateJson(JSON.stringify(current));
  }

  public async delete(id: number): Promise<void> {
    const current: KmpCapturePayload = await this.requireRaw(id);
    KmpPersistenceService.getInstance().captureDeleteJson(current.uid, new Date().toISOString());
  }

  private async requireRaw(id: number): Promise<KmpCapturePayload> {
    const state: KmpCaptureStatePayload = this.readState(KmpPersistenceService.getInstance().captureStateJson());
    for (let index = 0; index < state.items.length; index++) if (await this.idFor(state.items[index].uid) === id) return state.items[index];
    throw new Error('KMP capture not found');
  }

  private async toInspiration(item: KmpCapturePayload): Promise<InspirationItem> {
    return { id: await this.idFor(item.uid), text: item.text, createdAt: item.createdAt, updatedAt: item.updatedAt };
  }

  private readState(payload: string): KmpCaptureStatePayload { return JSON.parse(payload) as KmpCaptureStatePayload; }

  private async idFor(uid: string): Promise<number> {
    const store: preferences.Preferences = this.requireStore();
    const key: string = KmpCaptureRepositoryAdapter.ID_PREFIX + uid;
    const value: preferences.ValueType = await store.get(key, 0);
    if (typeof value === 'number' && value > 0) return value;
    const nextValue: preferences.ValueType = await store.get(KmpCaptureRepositoryAdapter.NEXT_ID_KEY, 1300000000);
    const next: number = typeof nextValue === 'number' && nextValue > 0 ? nextValue : 1300000000;
    await store.put(key, next); await store.put(KmpCaptureRepositoryAdapter.NEXT_ID_KEY, next + 1); await store.flush(); return next;
  }

  private async bindId(uid: string, id: number): Promise<void> {
    const store: preferences.Preferences = this.requireStore();
    await store.put(KmpCaptureRepositoryAdapter.ID_PREFIX + uid, id);
    await store.flush();
  }

  private requireStore(): preferences.Preferences { if (this.store === null) throw new Error('KMP capture adapter is not initialized'); return this.store; }
}
