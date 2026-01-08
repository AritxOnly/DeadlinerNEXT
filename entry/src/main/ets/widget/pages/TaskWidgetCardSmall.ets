import { WidgetData, WidgetTaskItem } from '../model/WidgetData';

@Entry
@Component
struct TaskWidgetCardSmall {
  @LocalStorageProp('widgetData') data: WidgetData = new WidgetData();

  // --- 颜色资源 ---
  readonly COLOR_ACCENT: Resource = $r('app.color.accent');
  readonly COLOR_BRAND: Resource = $r('app.color.brand');
  readonly COLOR_WIDGET_BG_START: Resource = $r('app.color.widget_bg_grad_start');
  readonly COLOR_WIDGET_BG_END: Resource = $r('app.color.widget_bg_grad_end');

  readonly COLOR_ITEM_BG: Resource = $r('app.color.widget_item_bg');
  // 自定义背景下的半透明 Item 背景
  readonly COLOR_SEMI_ITEM_BG: ResourceColor = '#99000000';
  readonly COLOR_SEMI_WHITE_BG: ResourceColor = '#99FFFFFF';

  readonly FONT_PRIMARY: Resource = $r('app.color.font_primary');
  readonly FONT_SECONDARY: Resource = $r('app.color.font_secondary');

  /**
   * 判断是否使用了自定义背景
   */
  isCustomBg(): boolean {
    return !!(this.data.backgroundImage && this.data.backgroundImage.length > 0);
  }

  /**
   * 判断是否使用白色文字（根据图片分析结果）
   */
  isWhiteText(): boolean {
    if (!this.data.backgroundImage) return false;
    return this.data.isWhiteText;
  }

  /**
   * 获取 Item 背景颜色
   */
  getItemBgColor(): ResourceColor {
    if (this.data.backgroundImage && this.data.backgroundImage.length > 0) {
      if (this.isWhiteText()) {
        return this.COLOR_SEMI_ITEM_BG; // 半透明黑
      } else {
        return this.COLOR_SEMI_WHITE_BG; // 半透明白
      }
    }
    return this.COLOR_ITEM_BG;
  }

  /**
   * 获取主要文字颜色
   */
  getPrimaryFontColor(): ResourceColor {
    if (this.data.backgroundImage) {
      return this.isWhiteText() ? Color.White : '#E6000000';
    }
    return this.FONT_PRIMARY;
  }

  /**
   * 获取次要文字颜色
   */
  getSecondaryFontColor(): ResourceColor {
    if (this.data.backgroundImage) {
      return this.isWhiteText() ? '#CCFFFFFF' : '#99000000';
    }
    return this.FONT_SECONDARY;
  }

  aboutToAppear() {
    console.info(`[TaskWidgetCardSmall] Initialized.`);
  }

  build() {
    Stack() {
      // --- 1. 背景层 ---
      if (this.data.backgroundImage && this.data.backgroundImage.length > 0) {
        // A. 自定义背景图片 (保持不变)
        Image(this.data.backgroundImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        // B. 默认渐变背景 + 水波纹效果 (修改处)
        Stack() {
          // 1.1 基础渐变底色
          Rect()
            .width('100%')
            .height('100%')
            .fill(this.COLOR_WIDGET_BG_START)
            .linearGradient({
              angle: 135,
              colors: [
                [this.COLOR_WIDGET_BG_START, 0.0],
                [this.COLOR_WIDGET_BG_END, 1.0]
              ]
            })

          // 1.2 波纹 - 外圈 (大，极淡)
          Circle()
            .width(200) // 2x2 尺寸较大，圆圈可以画大一点
            .height(200)
            .fill(this.COLOR_BRAND)
            .opacity(0.03) // 非常淡，作为背景氛围
            .position({ x: '30%', y: '-20%' }) // 从右上角晕开

          // 1.3 波纹 - 中圈 (稍小，稍显)
          Circle()
            .width(140)
            .height(140)
            .fill(this.COLOR_BRAND)
            .opacity(0.06)
            .position({ x: '55%', y: '-5%' })
        }
        .width('100%')
        .height('100%')
      }

      // --- 2. 内容层 (保持不变) ---
      Column() {
        // --- 顶部栏 ---
        Row() {
          Image($r('app.media.icon'))
            .width(18)
            .height(18)
            .borderRadius(4)
            .margin({ right: 6 })

          Text("Deadliner")
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPrimaryFontColor())
            .layoutWeight(1)
            .maxLines(1)
            .textShadow(this.data.backgroundImage ? { radius: 2, color: '#40000000' } : undefined)

          if (this.data.totalCount > 0) {
            Text(`${this.data.totalCount}`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.data.totalCount > 3 ? this.COLOR_ACCENT : this.COLOR_BRAND)
              .backgroundColor(this.getItemBgColor())
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(6)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // --- 任务列表 ---
        if (this.data.tasks.length === 0) {
          this.EmptyState()
        } else {
          List({ space: 6 }) {
            ForEach(this.data.tasks.slice(0, 3), (item: WidgetTaskItem) => {
              ListItem() {
                this.CompactTaskItem(item)
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .padding(10)
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { target: 'main' }
      });
    })
  }

  @Builder
  CompactTaskItem(item: WidgetTaskItem) {
    Row() {
      // 左侧指示条
      Column()
        .width(3)
        .height(12)
        .backgroundColor(item.isUrgent ? this.COLOR_ACCENT : this.COLOR_BRAND)
        .borderRadius(1.5)
        .margin({ right: 6 })

      // 标题
      Text(item.title)
        .fontSize(12)
        .fontColor(this.getPrimaryFontColor())
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 时间
      Text(item.timeDesc)
        .fontSize(10)
        .fontColor(item.isUrgent ? this.COLOR_ACCENT : this.getSecondaryFontColor())
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .margin({ left: 4 })
        .maxLines(1)
        .flexShrink(0)
    }
    .width('100%')
    .height(30)
    .backgroundColor(this.getItemBgColor())
    .borderRadius(8)
    .padding({ left: 6, right: 8 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: (item.isUrgent && !this.data.backgroundImage) ? 1 : 0,
      color: this.COLOR_ACCENT
    })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('🎉')
        .fontSize(30)
        .margin({ bottom: 4 })
        .textShadow(this.data.backgroundImage ? { radius: 10, color: '#80FFFFFF' } : undefined)

      Text("全部搞定")
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.FONT_PRIMARY)
        .opacity(0.8)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

@Builder
export function TaskWidgetCardSmallPreviewBuilder() {
  TaskWidgetCardSmall()
    .borderRadius(20)
    .clip(true)
    .width(150)
    .height(150)
}