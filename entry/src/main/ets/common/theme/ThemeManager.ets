import { ITheme, ThemeMap } from "./ThemeModel";
import { ThemeControl } from "@kit.ArkUI";
import { DeadlinerTheme } from "../../AppTheme";
import { LocalValues } from "../local/LocalValues";
import { preferences } from '@kit.ArkData'; // 👈 必须引用

export class ThemeManager {
  private static pref: preferences.Preferences | undefined = undefined;
  private static readonly STORE_NAME = 'deadliner_theme_config';
  private static readonly KEY_THEME = 'key_current_theme';

  /**
   * 初始化
   */
  static async init(context: Context) {
    try {
      ThemeManager.pref = await preferences.getPreferences(context, ThemeManager.STORE_NAME);

      // 读取 Key
      const key = await ThemeManager.pref.get(ThemeManager.KEY_THEME, 'classic') as string;

      console.info('[ThemeManager]', `Loaded from disk: ${key}`);

      let validKey = key;
      if (!ThemeMap[validKey]) {
        validKey = 'classic';
      }

      AppStorage.setOrCreate('currentThemeKey', validKey);
      AppStorage.setOrCreate('currentTheme', ThemeMap[validKey]);

      ThemeManager.applySystemTheme(ThemeMap[validKey]);

    } catch (err) {
      console.error('[ThemeManager]', 'Init failed', JSON.stringify(err));
      AppStorage.setOrCreate('currentThemeKey', 'classic');
      AppStorage.setOrCreate('currentTheme', ThemeMap['classic']);
      ThemeManager.applySystemTheme(ThemeMap['classic']);
    }
  }

  /**
   * 切换主题
   */
  static async switchTheme(name: string) {
    if (ThemeMap[name]) {
      console.info('[ThemeManager]', `Switching to: ${name}`);

      const newTheme = ThemeMap[name];
      AppStorage.set('currentTheme', newTheme);
      AppStorage.set('currentThemeKey', name);
      ThemeManager.applySystemTheme(newTheme);

      if (ThemeManager.pref) {
        try {
          await ThemeManager.pref.put(ThemeManager.KEY_THEME, name);
          await ThemeManager.pref.flush();
          console.info('[ThemeManager]', 'Persisted to disk successfully.');
        } catch (e) {
          console.error('[ThemeManager]', 'Flush failed', e);
        }
      }
    }
  }

  private static applySystemTheme(theme: ITheme) {
    try {
      ThemeControl.setDefaultTheme(new DeadlinerTheme(theme));
    } catch (error) {
      console.error('[ThemeManager]', 'Failed to apply system theme', error);
    }
  }

  static getCurrentTheme(): ITheme {
    return AppStorage.get<ITheme>('currentTheme') || ThemeMap['classic'];
  }

  // static createCustomTheme(seedColor: string): ITheme {
  //   return {
  //     brand: seedColor,
  //     brand50: seedColor, // 这里的逻辑后续需要完善
  //     accent: seedColor,
  //     bgPrimary: '#F2F3F5'
  //   };
  // }
}