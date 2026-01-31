import { ITheme, ThemeMap } from "./ThemeModel";

export class ThemeManager {
  static init() {
    AppStorage.setOrCreate('currentTheme', ThemeMap['classic']);
  }

  static switchTheme(themeName: string) {
    if (ThemeMap[themeName]) {
      AppStorage.set('currentTheme', ThemeMap[themeName]);
    }
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