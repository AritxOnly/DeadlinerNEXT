import { createTheme, INDICATORS_MORANDI, INDICATORS_VIBRANT, ITheme, ThemeMap } from "./ThemeModel";
import { ThemeControl } from "@kit.ArkUI";
import { DeadlinerTheme } from "../../AppTheme";
import { preferences } from '@kit.ArkData';
import { ColorGenerator, ThemePalette } from "../../utils/ColorGenerator";

export class ThemeManager {
  private static pref: preferences.Preferences | undefined = undefined;
  private static readonly STORE_NAME = 'deadliner_theme_config';
  private static readonly KEY_THEME = 'key_current_theme';
  private static readonly KEY_CUSTOM_HUE = 'key_custom_hue';
  private static readonly KEY_CUSTOM_TYPE = 'key_custom_type'; // 'vibrant' | 'morandi'

  static async init(context: Context) {
    try {
      ThemeManager.pref = await preferences.getPreferences(context, ThemeManager.STORE_NAME);
      const key = await ThemeManager.pref.get(ThemeManager.KEY_THEME, 'classic') as string;

      if (key === 'custom') {
        const hue = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_HUE, 210) as number;
        const type = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_TYPE, 'vibrant') as string;
        ThemeManager.applyCustomTheme(hue, type);
      } else {
        let validKey = ThemeMap[key] ? key : 'classic';
        ThemeManager.updateAppState(validKey, ThemeMap[validKey]);
      }
    } catch (err) {
      ThemeManager.updateAppState('classic', ThemeMap['classic']);
    }
  }

  /**
   * 应用自定义主题
   */
  static async applyCustomTheme(hue: number, type: string) {
    let palette: ThemePalette;
    if (type === 'morandi') {
      palette = ColorGenerator.generateMorandi(hue);
    } else {
      palette = ColorGenerator.generateVibrant(hue);
    }

    const customTheme = ThemeManager.createCustomTheme(palette, type);

    // 1. 更新内存状态
    ThemeManager.updateAppState('currentTheme', customTheme);

    if (ThemeManager.pref) {
      await ThemeManager.pref.put(ThemeManager.KEY_THEME, 'custom');
      await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_HUE, hue);
      await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_TYPE, type);
      await ThemeManager.pref.flush();
    }
  }

  /**
   * 核心方法：将 Palette 映射到全套 ITheme
   */
  static createCustomTheme(palette: ThemePalette, type: string): ITheme {
    const withAlpha = (hex: string, alpha: string) => {
      return hex.replace('#', '#' + alpha);
    };

    return createTheme(
      palette.primary,
      withAlpha(palette.primary, "80"),
      palette.tertiary,
      $r('app.color.background_primary'),
      (type === 'vibrant') ? INDICATORS_VIBRANT : INDICATORS_MORANDI
    )
  }

  private static updateAppState(key: string, theme: ITheme) {
    AppStorage.setOrCreate('currentThemeKey', key);
    AppStorage.setOrCreate('currentTheme', theme);
    ThemeManager.applySystemTheme(theme);
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
}