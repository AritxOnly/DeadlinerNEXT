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