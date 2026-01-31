import { CustomColors, CustomTheme } from '@kit.ArkUI'
import { ITheme } from './common/theme/ThemeModel'

export class DeadlinerColors implements CustomColors {
  // 移除内部直接获取 ThemeManager 的逻辑，改为外部传入

  // 品牌色
  brand: ResourceColor

  // 告警/确认
  warning: ResourceColor = $r('app.color.warning')
  alert: ResourceColor
  confirm: ResourceColor = $r('app.color.confirm')

  // 文本
  fontPrimary: ResourceColor = $r('app.color.font_primary')
  fontSecondary: ResourceColor = $r('app.color.font_secondary')
  fontEmphasize: ResourceColor = $r('app.color.font_emphasize')

  // 图标
  iconPrimary: ResourceColor = $r('app.color.icon_primary')
  iconSecondary: ResourceColor = $r('app.color.icon_secondary')
  iconEmphasize: ResourceColor = $r('app.color.icon_emphasize')

  // 背景
  backgroundPrimary: ResourceColor
  backgroundSecondary: ResourceColor = $r('app.color.background_secondary')
  backgroundTertiary: ResourceColor = $r('app.color.background_tertiary')
  backgroundEmphasize: ResourceColor = $r('app.color.background_emphasize')

  // 分割线
  compDivider: ResourceColor = $r('app.color.comp_divider')

  // 通用交互
  interactiveActive: ResourceColor = $r('app.color.interactive_active')
  interactiveSelect: ResourceColor = $r('app.color.interactive_select')
  interactivePressed: ResourceColor = $r('app.color.interactive_pressed')

  // 构造函数：接收当前的 ITheme 配置
  constructor(theme: ITheme) {
    this.brand = theme.brand
    this.alert = theme.brand // 复用 brand
    this.backgroundPrimary = theme.bgPrimary
  }
}

export class DeadlinerTheme implements CustomTheme {
  public colors: DeadlinerColors

  constructor(theme: ITheme) {
    this.colors = new DeadlinerColors(theme)
  }
}