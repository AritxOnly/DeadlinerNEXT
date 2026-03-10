import preferences from '@ohos.data.preferences';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';

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

  private readonly storageKey = "deadliner_local_memories";
  private readonly storageProfileKey = "deadliner_user_profile";
  private readonly prefName = "deadliner_memory_store";

  private readonly maxFragments = 60;
  private readonly maxAgeDays = 120;

  private pref: preferences.Preferences | null = null;

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
    if (this.pref) return; // 避免重复初始化
    this.pref = await preferences.getPreferences(context, this.prefName);
    await this.loadFromDisk();
    await this.loadProfileFromDisk();
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

    this.fragments.push(newFrag);
    this.pruneMemories();
    await this.saveToDisk();
  }

  public async saveUserProfile(profile: string): Promise<void> {
    const trimmed = profile.trim();
    if (!trimmed) return;

    this.userProfile = trimmed;
    await this.saveProfileToDisk();
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
    this.userProfile = profile.trim();
    await this.saveProfileToDisk();
  }

  public async deleteFragment(id: string): Promise<void> {
    this.fragments = this.fragments.filter(f => f.id !== id);
    await this.saveToDisk();
  }

  public async updateFragment(id: string, newContent: string, newCategory?: string, newImportance?: number): Promise<void> {
    const trimmed = newContent.trim();
    const idx = this.fragments.findIndex(f => f.id === id);
    if (idx === -1) return;

    const old = this.fragments[idx];
    this.fragments[idx] = {
      id: old.id,
      content: !trimmed ? old.content : trimmed,
      category: newCategory ?? old.category,
      timestamp: old.timestamp,
      importance: newImportance ?? old.importance
    };

    await this.saveToDisk();
  }

  public async replaceAllFragments(newList: MemoryFragment[]): Promise<void> {
    this.fragments = newList;
    await this.saveToDisk();
  }

  public async clearAllMemories(): Promise<void> {
    this.fragments = [];
    this.userProfile = "";
    if (this.pref) {
      await this.pref.delete(this.storageKey);
      await this.pref.delete(this.storageProfileKey);
      await this.pref.flush();
    }
  }

  // MARK: - Private Helpers

  private pruneMemories() {
    // 1) 先按时间过期淘汰
    const cutoff = Date.now() - (this.maxAgeDays * 24 * 60 * 60 * 1000);
    this.fragments = this.fragments.filter(f => f.timestamp >= cutoff);

    // 2) 超容量：优先删“低重要度 + 更旧”的
    if (this.fragments.length > this.maxFragments) {
      this.fragments.sort((a, b) => {
        if (a.importance !== b.importance) {
          return b.importance - a.importance; // 重要度高的排前面
        }
        return b.timestamp - a.timestamp; // 时间新的排前面
      });
      this.fragments = this.fragments.slice(0, this.maxFragments);
    }
  }

  // MARK: - Local Persistence

  private async saveToDisk(): Promise<void> {
    if (!this.pref) return;
    const encoded = JSON.stringify(this.fragments);
    await this.pref.put(this.storageKey, encoded);
    await this.pref.flush();
  }

  private async loadFromDisk(): Promise<void> {
    if (!this.pref) return;
    const data = await this.pref.get(this.storageKey, "") as string;
    if (data) {
      try {
        this.fragments = JSON.parse(data) as MemoryFragment[];
      } catch (e) {
        console.error("MemoryBank", "Failed to parse memories from disk");
      }
    }
  }

  private async saveProfileToDisk(): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(this.storageProfileKey, this.userProfile);
    await this.pref.flush();
  }

  private async loadProfileFromDisk(): Promise<void> {
    if (!this.pref) return;
    this.userProfile = await this.pref.get(this.storageProfileKey, "") as string;
  }
}