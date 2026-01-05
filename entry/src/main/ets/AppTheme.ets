import type { CustomColors, CustomTheme } from '@kit.ArkUI'

export class DeadlinerColors implements CustomColors {
  // 品牌色
  brand: ResourceColor = $r('app.color.brand')

  // 告警/确认色先复用品牌色，有需要再拆
  warning: ResourceColor = $r('app.color.warning')
  alert: ResourceColor = $r('app.color.brand')
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
  backgroundPrimary: ResourceColor = $r('app.color.background_primary')
  backgroundSecondary: ResourceColor = $r('app.color.background_secondary')
  backgroundTertiary: ResourceColor = $r('app.color.background_tertiary')
  backgroundEmphasize: ResourceColor = $r('app.color.background_emphasize')

  // 分割线
  compDivider: ResourceColor = $r('app.color.comp_divider')

  // 通用交互
  interactiveActive: ResourceColor = $r('app.color.interactive_active')
  interactiveSelect: ResourceColor = $r('app.color.interactive_select')
  interactivePressed: ResourceColor = $r('app.color.interactive_pressed')
}

export class DeadlinerTheme implements CustomTheme {
  public colors: DeadlinerColors = new DeadlinerColors()
}

export const gDeadlinerTheme: CustomTheme = new DeadlinerTheme()