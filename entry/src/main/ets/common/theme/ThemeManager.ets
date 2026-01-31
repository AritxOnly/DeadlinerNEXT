import { ITheme, ThemeMap } from "./ThemeModel";
import { ThemeControl } from "@kit.ArkUI";
import { DeadlinerTheme } from "../../AppTheme";

export class ThemeManager {
  static init() {
    let targetTheme: ITheme;

    if (AppStorage.has('currentTheme')) {
      targetTheme = AppStorage.get<ITheme>('currentTheme')!;
    } else {
      targetTheme = ThemeMap['harmony'];
      AppStorage.setOrCreate('currentTheme', targetTheme);
    }

    ThemeManager.applySystemTheme(targetTheme);
  }

  static switchTheme(name: string) {
    if (ThemeMap[name]) {
      const newTheme = ThemeMap[name];

      AppStorage.set('currentTheme', newTheme);

      ThemeManager.applySystemTheme(newTheme);
    }
  }

  private static applySystemTheme(theme: ITheme) {
    ThemeControl.setDefaultTheme(new DeadlinerTheme(theme));
  }

  static getCurrentTheme(): ITheme {
    return AppStorage.get<ITheme>('currentTheme') || ThemeMap['classic'];
  }

  static createCustomTheme(seedColor: string): ITheme {
    return {
      brand: seedColor,
      brand50: seedColor,
      accent: seedColor,
      bgPrimary: '#F2F3F5'
    };
  }
}