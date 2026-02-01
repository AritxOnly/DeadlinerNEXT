import { createTheme, CustomThemeConfig, INDICATORS_MORANDI, INDICATORS_VIBRANT, ITheme, ThemeMap } from "./ThemeModel";
import { ThemeControl } from "@kit.ArkUI";
import { DeadlinerTheme } from "../../AppTheme";
import { preferences } from '@kit.ArkData';

export class ThemeManager {
  private static pref: preferences.Preferences | undefined = undefined;
  private static readonly STORE_NAME = 'deadliner_theme_config';
  private static readonly KEY_THEME = 'key_current_theme';

  private static readonly KEY_CUSTOM_BRAND = 'key_custom_brand';
  private static readonly KEY_CUSTOM_ACCENT = 'key_custom_accent';
  private static readonly KEY_CUSTOM_TAB_ICON = 'key_custom_tab_icon';
  private static readonly KEY_CUSTOM_MORANDI = 'key_custom_morandi';

  private static readonly KEY_PARAM_HUE = 'key_param_hue';
  private static readonly KEY_PARAM_STYLE = 'key_param_style';

  static async init(context: Context) {
    try {
      ThemeManager.pref = await preferences.getPreferences(context, ThemeManager.STORE_NAME);
      const key = await ThemeManager.pref.get(ThemeManager.KEY_THEME, 'classic') as string;

      if (key === 'custom') {
        const brand = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BRAND, '#FF0A59F7') as string;
        const accent = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_ACCENT, '#FF0A59F7') as string;
        const tabIcon = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_TAB_ICON, '') as string;
        const morandi = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_MORANDI, false) as boolean;

        // 恢复主题
        ThemeManager.applyCustomColors(brand, accent, tabIcon || undefined, morandi, 210, 50, false); // false表示初始化时不需重复存入磁盘
      } else {
        let validKey = ThemeMap[key] ? key : 'classic';
        ThemeManager.updateAppState(validKey, ThemeMap[validKey]);
      }
    } catch (err) {
      console.error('[ThemeManager] Init failed:', err);
      ThemeManager.updateAppState('classic', ThemeMap['classic']);
    }
  }

  /**
   * ✅ 获取当前自定义配置（供 ColorCustomizer 初始化使用）
   */
  static async getCustomConfig(): Promise<CustomThemeConfig> {
    if (!ThemeManager.pref) return { hue: 210, styleStrength: 50, isCustom: false, brand: '', accent: '', isMorandi: false };

    const currentKey = await ThemeManager.pref.get(ThemeManager.KEY_THEME, 'classic') as string;
    const hue = await ThemeManager.pref.get(ThemeManager.KEY_PARAM_HUE, 210) as number;
    const style = await ThemeManager.pref.get(ThemeManager.KEY_PARAM_STYLE, 50) as number;
    const brand = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_BRAND, '') as string;
    const accent = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_ACCENT, '') as string;
    const morandi = await ThemeManager.pref.get(ThemeManager.KEY_CUSTOM_MORANDI, false) as boolean;

    return {
      hue: hue,
      styleStrength: style,
      isCustom: currentKey === 'custom',
      brand: brand,
      accent: accent,
      isMorandi: morandi
    };
  }

  /**
   * ✅ 应用自定义颜色
   * 增加了 hue 和 styleStrength 参数用于存储状态
   */
  static async applyCustomColors(
    brand: string, accent: string,
    tabIcon: string | ResourceColor | undefined,
    morandi: boolean,
    hue: number,
    styleStrength: number,
    saveToDisk: boolean = true
  ) {
    const customTheme = ThemeManager.createCustomTheme(brand, accent, tabIcon, morandi);

    ThemeManager.updateAppState('currentTheme', customTheme);

    if (saveToDisk && ThemeManager.pref) {
      try {
        await ThemeManager.pref.put(ThemeManager.KEY_THEME, 'custom');
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_BRAND, brand);
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_ACCENT, accent);
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_TAB_ICON, tabIcon ? tabIcon.toString() : '');
        await ThemeManager.pref.put(ThemeManager.KEY_CUSTOM_MORANDI, morandi);

        // ✅ 保存滑块状态
        await ThemeManager.pref.put(ThemeManager.KEY_PARAM_HUE, hue);
        await ThemeManager.pref.put(ThemeManager.KEY_PARAM_STYLE, styleStrength);

        await ThemeManager.pref.flush();
      } catch (e) {
        console.error('[ThemeManager] Failed to save custom colors', e);
      }
    }
  }

  /**
   * 核心方法：将颜色字符串映射到全套 ITheme
   */
  private static createCustomTheme(
    brand: string, accent: string, tabIcon?: string | ResourceColor,
    morandi: boolean = false
  ): ITheme {
    // 简单的透明度处理工具
    const withAlpha = (hex: string, alpha: string) => {
      // 假设传入的是 #RRGGBB 格式，直接追加 alpha
      // 如果已经是 #AARRGGBB 则需特殊处理，这里简化处理
      if (hex.length === 9) return hex; // 已经是8位hex
      return hex.replace('#', '#' + alpha);
    };

    // 如果未指定 tabIcon，默认使用 accent
    const activeTabColor = tabIcon || accent;

    return createTheme(
      brand,                          // brand
      withAlpha(brand, "80"),         // brand50
      accent,                         // accent
      $r('app.color.background_primary'),
      morandi ? INDICATORS_MORANDI : INDICATORS_VIBRANT,
      activeTabColor,                 // tabIcon
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
      console.info('[ThemeManager]', `Switching to preset: ${name}`);

      const newTheme = ThemeMap[name];
      AppStorage.set('currentTheme', newTheme);
      AppStorage.set('currentThemeKey', name);
      ThemeManager.applySystemTheme(newTheme);

      if (ThemeManager.pref) {
        try {
          await ThemeManager.pref.put(ThemeManager.KEY_THEME, name);
          await ThemeManager.pref.flush();
        } catch (e) {
          console.error('[ThemeManager]', 'Flush failed', e);
        }
      }
    }
  }
}