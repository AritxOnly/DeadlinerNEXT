export interface ITheme {
  brand: ResourceColor;
  brand50: ResourceColor;
  accent: ResourceColor;
  bgPrimary: ResourceColor;
}

export const ThemeMap: Record<string, ITheme> = {
  'classic': {
    brand: $r('app.color.brand'),
    brand50: $r('app.color.brand_50'),
    accent: $r('app.color.accent'),
    bgPrimary: $r('app.color.background_primary')
  },

  // 'vibrant': {
  //   brand: $r('app.color.brand_vibrant'),
  //   accent: $r('app.color.accent_vibrant'),
  //   bgPrimary: $r('app.color.background_primary')
  // },

  'harmony': {
    brand: $r('sys.color.ohos_id_color_emphasize'),
    brand50: $r('sys.color.ohos_id_color_secondary'),
    accent: $r('sys.color.ohos_id_color_warning'),
    bgPrimary: $r('sys.color.ohos_id_color_background')
  }
};