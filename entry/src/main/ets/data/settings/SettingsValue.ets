import { preferences } from '@kit.ArkData';
import { SettingsConstants as C } from './SettingsConstants';
import { BusinessError } from '@kit.BasicServicesKit';

interface WebDavAuthInterface {
  user: string;
  pass: string;
}

export class SettingsValue {
  private static instance: SettingsValue;
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): SettingsValue {
    if (!SettingsValue.instance) {
      SettingsValue.instance = new SettingsValue();
    }
    return SettingsValue.instance;
  }

  /**
   * 初始化：通常在 EntryAbility 的 onCreate 或 onWindowStageCreate 调用
   */
  async init(context: Context): Promise<void> {
    try {
      // 1. 获取 Preferences 实例
      this.pref = await preferences.getPreferences(context, C.PREF_NAME);

      // 2. 读取数据并载入 AppStorage
      // AppStorage 是内存中的全局状态，UI 可以通过 @StorageLink 直接绑定

      // 同步开关 (默认 false)
      const syncEnable = await this.pref.get(C.KEY_CLOUD_SYNC_ENABLE, false);
      AppStorage.setOrCreate(C.KEY_CLOUD_SYNC_ENABLE, syncEnable);

      // WebDAV URL (默认空)
      const url = await this.pref.get(C.KEY_WEBDAV_URL, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_URL, url);

      // Username
      const username = await this.pref.get(C.KEY_WEBDAV_USERNAME, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_USERNAME, username);

      // Password
      const password = await this.pref.get(C.KEY_WEBDAV_PASSWORD, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_PASSWORD, password);

      // Vibration
      const vibration = await this.pref.get(C.KEY_VIBRATION_ENABLE, true)
      AppStorage.setOrCreate(C.KEY_VIBRATION_ENABLE, vibration)

      console.info('SettingsValue initialized successfully');
    } catch (err) {
      console.error(`Failed to load settings: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 通用设置方法：同时更新 AppStorage (UI) 和 Preferences (Disk)
   */
  async setValue<T extends preferences.ValueType>(key: string, value: T): Promise<void> {
    if (!this.pref) return;

    // 1. 更新内存状态 (触发 UI 刷新)
    AppStorage.set(key, value);

    // 2. 持久化到磁盘
    try {
      await this.pref.put(key, value);
      await this.pref.flush(); // 必须 flush 才能真正写入文件
    } catch (err) {
      console.error(`Failed to save ${key}: ${JSON.stringify(err)}`);
    }
  }

  // ================= 快捷存取方法 (Optional) =================
  // 虽然 UI 可以直接用 @StorageLink，但在逻辑层(如 SyncService)中，
  // 我们可能更习惯调用方法获取值。

  getCloudSyncEnable(): boolean {
    return AppStorage.get<boolean>(C.KEY_CLOUD_SYNC_ENABLE) ?? false;
  }

  async setCloudSyncEnable(enable: boolean) {
    await this.setValue(C.KEY_CLOUD_SYNC_ENABLE, enable);
  }

  getWebDavUrl(): string {
    return AppStorage.get<string>(C.KEY_WEBDAV_URL) ?? '';
  }

  async setWebDavUrl(url: string) {
    await this.setValue(C.KEY_WEBDAV_URL, url);
  }

  getWebDavAuth(): WebDavAuthInterface {
    return {
      user: AppStorage.get<string>(C.KEY_WEBDAV_USERNAME) ?? '',
      pass: AppStorage.get<string>(C.KEY_WEBDAV_PASSWORD) ?? ''
    };
  }

  async setWebDavAuth(user: string, pass: string) {
    // 批量写入建议直接操作 pref 减少 flush 次数，这里简单处理调用两次
    await this.setValue(C.KEY_WEBDAV_USERNAME, user);
    await this.setValue(C.KEY_WEBDAV_PASSWORD, pass);
  }

  getVibration(): boolean {
    return AppStorage.get<boolean>(C.KEY_VIBRATION_ENABLE) ?? true;
  }

  async setVibration(status: boolean) {
    await this.setValue(C.KEY_VIBRATION_ENABLE, status);
  }
}