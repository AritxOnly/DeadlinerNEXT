import { LengthMetrics } from "@kit.ArkUI";

/**
 * SettingsSection: 类似 Android 的 Surface 容器
 * 绘制一个大圆角的卡片背景
 */
@Component
export struct SettingsSection {
  title?: string | Resource;
  @BuilderParam content: () => void;

  build() {
    Column() {
      // Section 标题 (TopLabel)
      if (this.title) {
        Text(this.title)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 24, bottom: 8 }) // 对齐卡片内部文字
          .width('100%')
      }

      // 卡片容器
      Column() {
        this.content()
      }
      .width('100%')
      // 核心样式：背景色 + 大圆角 (24vp)
      .backgroundColor($r('app.color.background_secondary'))
      .borderRadius(24)
      .padding(4) // 让内部 Item 离边缘有间隙 (对应 Android 的 container padding)
      .margin({ left: 16, right: 16 }) // 卡片离屏幕两边的距离
    }
    .width('100%')
  }
}

/**
 * SettingsItem: 具体的设置项按钮
 * 包含：左侧图标、标题、副标题、右侧箭头容器
 */
@Component
export struct SettingsItem {
  title: string | Resource = '';
  subtitle?: string | Resource;
  icon?: Resource;
  onItemClick?: () => void;

  // 内部状态，用于处理按压效果
  @State isPressed: boolean = false;

  build() {
    Row() {
      if (this.icon) {
        SymbolGlyph(this.icon) // 推荐使用 Symbol，如果用 PNG 改用 Image
          .fontSize(24)
          .fontColor([$r('app.color.font_primary')])
          .margin({ right: 16 })
      }

      // 2. Headline & Supporting Text (中间文字)
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold) // 对应 TitleMediumEmphasized
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12) // 对应 BodySmall
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE }) // 跑马灯效果
        }
      }
      .layoutWeight(1) // 占满剩余空间
      .alignItems(HorizontalAlign.Start)

    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 }) // 内部 Padding
    .borderRadius(20) // 按钮自身的圆角 (比容器略小)
    .margin({ top: 2, bottom: 2, start: LengthMetrics.vp(2), end: LengthMetrics.vp(2) }) // 按钮离容器边缘的间隙
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent) // 点击态
    .animation({ duration: 200 }) // 简单的颜色过渡动画
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.onItemClick) this.onItemClick();
    })
  }
}

/**
 * SettingsSwitch: 带开关的设置项
 * 结构与 SettingsItem 保持一致，右侧为 Toggle 组件
 */
@Component
export struct SettingsSwitch {
  // 基础信息
  title: string | Resource = '';
  subtitle?: string | Resource;
  icon?: Resource;

  // 开关状态 (双向绑定或单向流均可，这里推荐使用 @Link 或 @Prop 配合 onChange)
  // 使用 @Prop 允许父组件单向控制，内部变化通过 onChange 通知
  @Prop isOn: boolean = false;

  // 状态改变回调
  onChange?: (isOn: boolean) => void;

  // 内部按压状态
  @State isPressed: boolean = false;

  build() {
    Row() {
      // 1. 左侧图标 (与 SettingsItem 保持一致)
      if (this.icon) {
        SymbolGlyph(this.icon)
          .fontSize(24)
          .fontColor([$r('app.color.font_primary')])
          .margin({ right: 16 })
      }

      // 2. 中间文字 (与 SettingsItem 保持一致)
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.subtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor($r('app.color.font_secondary'))
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 3. 右侧开关
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor($r('app.color.brand')) // 选中时的品牌色
        .switchPointColor('#FFFFFF') // 滑块颜色
        .height(24) // 限制高度，使其与图标协调
        .hitTestBehavior(HitTestMode.None) // [关键点]：让 Toggle 不拦截点击，事件交给 Row 统一处理
      // 注意：因为设置了 HitTestMode.None，这里的 onChange 不会被手指触发，
      // 而是依赖 Row 的 onClick 来改变 isOn 的值
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 }) // 保持与 SettingsItem 一致的内边距
    .borderRadius(20)
    .margin({ top: 2, bottom: 2, start: LengthMetrics.vp(2), end: LengthMetrics.vp(2) })
    .backgroundColor(this.isPressed ? $r('sys.color.ohos_id_color_click_effect') : Color.Transparent)
    .animation({ duration: 200 })
    // 按压效果
    .onTouch((event) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    // 统一处理点击逻辑
    .onClick(() => {
      // 触发回调，取反当前状态
      if (this.onChange) {
        this.onChange(!this.isOn);
      }
    })
  }
}

/**
 * SettingsDivider: 分割线
 * 根据设计，不应该通栏，而是只在文字部分下方
 */
@Component
export struct SettingsDivider {
  build() {
    Divider()
      .color($r('sys.color.ohos_id_color_list_separator'))
      .strokeWidth(0.5) // 细一点比较精致
      .margin({ left: 56, right: 16, top: 2, bottom: 2 }) // 左侧留出图标位置 (24+16+16)
  }
}