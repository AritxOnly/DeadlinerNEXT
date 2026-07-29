import { CustomColors, CustomTheme } from '@kit.ArkUI'
import { ITheme } from './common/theme/ThemeModel'

export class DeadlinerColors implements CustomColors {
  // 移除内部直接获取 ThemeManager 的逻辑，改为外部传入

  // 品牌色
  brand: ResourceColor
  primary: ResourceColor
  onPrimary: ResourceColor = $r('app.color.font_on_primary')
  container: ResourceColor = $r('app.color.background_secondary')

  // 告警/确认
  warning: ResourceColor = $r('app.color.warning')
  alert: ResourceColor
  confirm: ResourceColor = $r('app.color.confirm')

  // 文本
  fontPrimary: ResourceColor = $r('app.color.font_primary')
  fontSecondary: ResourceColor = $r('app.color.font_secondary')
  fontTertiary: ResourceColor = $r('app.color.font_tertiary')
  fontFourth: ResourceColor = $r('app.color.font_fourth')
  fontEmphasize: ResourceColor = $r('app.color.font_emphasize')
  fontOnPrimary: ResourceColor = $r('app.color.font_on_primary')

  // 图标
  iconPrimary: ResourceColor = $r('app.color.icon_primary')
  iconSecondary: ResourceColor = $r('app.color.icon_secondary')
  iconTertiary: ResourceColor = $r('app.color.icon_tertiary')
  iconFourth: ResourceColor = $r('app.color.icon_fourth')
  iconEmphasize: ResourceColor = $r('app.color.icon_emphasize')
  iconOnPrimary: ResourceColor = $r('app.color.icon_on_primary')

  // 背景
  backgroundPrimary: ResourceColor
  backgroundSecondary: ResourceColor = $r('app.color.background_secondary')
  backgroundTertiary: ResourceColor = $r('app.color.background_tertiary')
  backgroundFourth: ResourceColor = $r('app.color.background_emphasize')
  backgroundEmphasize: ResourceColor = $r('app.color.background_emphasize')

  // 组件表面
  compBackgroundPrimary: ResourceColor = $r('app.color.background_secondary')
  compBackgroundSecondary: ResourceColor = $r('app.color.background_tertiary')
  compBackgroundTertiary: ResourceColor = $r('app.color.background_primary_50')
  compBackgroundEmphasize: ResourceColor

  // 分割线
  compDivider: ResourceColor = $r('app.color.comp_divider')

  // 通用交互
  interactiveActive: ResourceColor = $r('app.color.interactive_active')
  interactiveSelect: ResourceColor = $r('app.color.interactive_select')
  interactivePressed: ResourceColor = $r('app.color.interactive_pressed')
  interactiveHover: ResourceColor = $r('app.color.interactive_select')
  interactiveFocus: ResourceColor
  interactiveClick: ResourceColor = $r('app.color.interactive_pressed')

  // 构造函数：接收当前的 ITheme 配置
  constructor(theme: ITheme) {
    this.brand = theme.brand
    this.primary = theme.brand
    this.alert = theme.brand // 复用 brand
    this.backgroundPrimary = theme.bgPrimary
    this.compBackgroundEmphasize = theme.brand
    this.interactiveFocus = theme.brand
  }
}

export class DeadlinerTheme implements CustomTheme {
  public colors: DeadlinerColors

  constructor(theme: ITheme) {
    this.colors = new DeadlinerColors(theme)
  }
}
