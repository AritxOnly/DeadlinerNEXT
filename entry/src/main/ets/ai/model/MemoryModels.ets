import util from '@ohos.util';
import common from '@ohos.app.ability.common';
import { KmpPersistenceService } from '../../common/kmp/KmpPersistenceService';

interface KmpMemoryPayload { uid: string; content: string; category: string; createdAt: string; importance: number; updatedAt: string; isDeleted: boolean; }
interface KmpProfilePayload { uid: string; nickname: string; avatarFileName: string | null; tier: string; createdAt: string; updatedAt: string; isDeleted: boolean; }
interface KmpMemoryProfileState { fragments: KmpMemoryPayload[]; profiles: KmpProfilePayload[]; }

export interface MemoryFragment {
  id: string;          // 替代 UUID
  content: string;
  category: string;
  timestamp: number;   // 替代 Date，使用毫秒级时间戳，便于 JSON 序列化和对比
  importance: number;
}

export class MemoryBank {
  private static instance: MemoryBank;

  public fragments: MemoryFragment[] = [];
  public userProfile: string = "";

  private initialized: boolean = false;

  private constructor() {}

  // 单例模式
  public static getInstance(): MemoryBank {
    if (!MemoryBank.instance) {
      MemoryBank.instance = new MemoryBank();
    }
    return MemoryBank.instance;
  }

  /**
   * 鸿蒙的 Preferences 需要 Context 来初始化
   * 建议在 EntryAbility 的 onCreate 或应用首页的 aboutToAppear 中调用
   */
  public async init(context: common.Context): Promise<void> {
    if (this.initialized) return;
    this.refreshFromKmp();
    this.initialized = true;
  }

  // MARK: - Core Functions

  public async saveMemory(content: string, category: string = "Auto"): Promise<void> {
    if (this.fragments.some(f => f.content === content)) return;

    const newFrag: MemoryFragment = {
      id: util.generateRandomUUID(true),
      content: content,
      category: category,
      timestamp: Date.now(),
      importance: 3
    };

    KmpPersistenceService.getInstance().memorySaveJson(JSON.stringify(this.toKmpFragment(newFrag)));
    this.refreshFromKmp();
  }

  public async saveUserProfile(profile: string): Promise<void> {
    const trimmed = profile.trim();
    if (!trimmed) return;

    await this.setUserProfileAllowEmpty(trimmed);
  }

  public getLongTermContext(maxProfileChars: number = 420, maxBullets: number = 6, maxTotalChars: number = 900): string {
    let parts: string[] = [];

    const p = this.userProfile.substring(0, maxProfileChars).trim();
    if (p) {
      parts.push(`【用户画像】\n${p}`);
    } else {
      parts.push(`【用户画像】\n(暂无)`);
    }

    if (this.fragments.length > 0 && maxBullets > 0) {
      // 获取最后的 maxBullets 条记录
      const recentFragments = this.fragments.slice(-maxBullets);
      const bullets = recentFragments.map(f => `- ${f.content}`).join("\n");
      parts.push(`【近期用户偏好/事实】\n${bullets}`);
    }

    const joined = parts.join("\n\n");
    return joined.substring(0, maxTotalChars);
  }

  // MARK: - Editing / Deleting

  public async setUserProfileAllowEmpty(profile: string): Promise<void> {
    const now = new Date().toISOString();
    const state: KmpMemoryProfileState = this.readKmpState();
    const current: KmpProfilePayload | null = state.profiles.length > 0 ? state.profiles[0] : null;
    const profilePayload: KmpProfilePayload = { uid: current === null ? util.generateRandomUUID(true) : current.uid, nickname: profile.trim(), avatarFileName: null, tier: 'FREE', createdAt: current === null ? now : current.createdAt, updatedAt: now, isDeleted: false };
    KmpPersistenceService.getInstance().profileSaveJson(JSON.stringify(profilePayload));
    this.refreshFromKmp();
  }

  public async deleteFragment(id: string): Promise<void> {
    KmpPersistenceService.getInstance().memoryDeleteJson(id, new Date().toISOString());
    this.refreshFromKmp();
  }

  public async updateFragment(id: string, newContent: string, newCategory?: string, newImportance?: number): Promise<void> {
    const trimmed = newContent.trim();
    const idx = this.fragments.findIndex(f => f.id === id);
    if (idx === -1) return;

    const old = this.fragments[idx];
    const updated: MemoryFragment = {
      id: old.id,
      content: !trimmed ? old.content : trimmed,
      category: newCategory ?? old.category,
      timestamp: old.timestamp,
      importance: newImportance ?? old.importance
    };
    KmpPersistenceService.getInstance().memorySaveJson(JSON.stringify(this.toKmpFragment(updated)));
    this.refreshFromKmp();
  }

  public async replaceAllFragments(newList: MemoryFragment[]): Promise<void> {
    for (let index = 0; index < this.fragments.length; index++) await this.deleteFragment(this.fragments[index].id);
    for (let index = 0; index < newList.length; index++) KmpPersistenceService.getInstance().memorySaveJson(JSON.stringify(this.toKmpFragment(newList[index])));
    this.refreshFromKmp();
  }

  public async clearAllMemories(): Promise<void> {
    for (let index = 0; index < this.fragments.length; index++) KmpPersistenceService.getInstance().memoryDeleteJson(this.fragments[index].id, new Date().toISOString());
    await this.setUserProfileAllowEmpty('');
  }

  private refreshFromKmp(): void {
    const state: KmpMemoryProfileState = this.readKmpState();
    const result: MemoryFragment[] = [];
    for (let index = 0; index < state.fragments.length; index++) {
      const item: KmpMemoryPayload = state.fragments[index];
      if (!item.isDeleted) result.push({ id: item.uid, content: item.content, category: item.category, timestamp: Date.parse(item.createdAt), importance: item.importance });
    }
    this.fragments = result;
    this.userProfile = state.profiles.length > 0 ? state.profiles[0].nickname : '';
  }

  private readKmpState(): KmpMemoryProfileState { return JSON.parse(KmpPersistenceService.getInstance().memoryProfileStateJson()) as KmpMemoryProfileState; }

  private toKmpFragment(fragment: MemoryFragment): KmpMemoryPayload {
    const createdAt: string = new Date(fragment.timestamp).toISOString();
    return { uid: fragment.id, content: fragment.content, category: fragment.category, createdAt: createdAt, importance: fragment.importance, updatedAt: new Date().toISOString(), isDeleted: false };
  }

}
