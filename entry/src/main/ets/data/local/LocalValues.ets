import { preferences } from '@kit.ArkData';
import { SettingsConstants as C } from './SettingsConstants';
import { SecureStorage } from './SecureStorage';

interface WebDavAuthInterface {
  user: string;
  pass: string;
}

export class LocalValues {
  private static instance: LocalValues;
  private pref: preferences.Preferences | null = null;

  private constructor() {}

  public static getInstance(): LocalValues {
    if (!LocalValues.instance) {
      LocalValues.instance = new LocalValues();
    }
    return LocalValues.instance;
  }

  async init(context: Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, C.PREF_NAME);

      // --- 1. 普通数据 (Preferences) ---
      const syncEnable = await this.pref.get(C.KEY_CLOUD_SYNC_ENABLE, false);
      AppStorage.setOrCreate(C.KEY_CLOUD_SYNC_ENABLE, syncEnable);

      const url = await this.pref.get(C.KEY_WEBDAV_URL, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_URL, url);

      const username = await this.pref.get(C.KEY_WEBDAV_USERNAME, '');
      AppStorage.setOrCreate(C.KEY_WEBDAV_USERNAME, username);

      const vibration = await this.pref.get(C.KEY_VIBRATION_ENABLE, true);
      AppStorage.setOrCreate(C.KEY_VIBRATION_ENABLE, vibration);

      // --- 2. 敏感数据 (Asset Store Kit) ---
      // 从安全存储中读取密码，加载到内存 AppStorage 供业务逻辑使用
      const password = await SecureStorage.get(C.KEY_WEBDAV_PASSWORD);
      AppStorage.setOrCreate(C.KEY_WEBDAV_PASSWORD, password);

      // 同理，如果是 API Key，也在这里加载
      // const apiKey = await SecureStorage.get('openai_api_key');
      // AppStorage.setOrCreate('openai_api_key', apiKey);

      console.info('SettingsValue initialized successfully');
    } catch (err) {
      console.error(`Failed to load settings: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 普通设置通用方法
   */
  async setValue<T extends preferences.ValueType>(key: string, value: T): Promise<void> {
    if (!this.pref) return;
    AppStorage.set(key, value); // 更新内存
    try {
      await this.pref.put(key, value); // 更新磁盘
      await this.pref.flush();
    } catch (err) {
      console.error(`Failed to save ${key}: ${JSON.stringify(err)}`);
    }
  }

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

  /**
   * 修改：WebDAV 认证信息设置
   * 用户名存 Prefs，密码存 Asset Store
   */
  async setWebDavAuth(user: string, pass: string) {
    // 1. 更新内存状态 (UI)
    AppStorage.set(C.KEY_WEBDAV_USERNAME, user);
    AppStorage.set(C.KEY_WEBDAV_PASSWORD, pass);

    // 2. 用户名 -> Preferences
    await this.setValue(C.KEY_WEBDAV_USERNAME, user);

    // 3. 密码 -> Asset Store Kit
    if (pass && pass.length > 0) {
      await SecureStorage.save(C.KEY_WEBDAV_PASSWORD, pass);
    } else {
      // 如果密码为空，视为删除
      await SecureStorage.delete(C.KEY_WEBDAV_PASSWORD);
    }
  }

  getVibration(): boolean {
    return AppStorage.get<boolean>(C.KEY_VIBRATION_ENABLE) ?? true;
  }

  async setVibration(status: boolean) {
    await this.setValue(C.KEY_VIBRATION_ENABLE, status);
  }
}