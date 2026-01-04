import { WidgetData, WidgetTaskItem } from '../model/WidgetData';

@Entry
@Component
struct TaskWidgetCardSmall {
  @LocalStorageProp('widgetData') data: WidgetData = new WidgetData();

  // 颜色资源
  readonly COLOR_ACCENT: Resource = $r('app.color.accent');
  readonly COLOR_BRAND: Resource = $r('app.color.brand');
  readonly COLOR_WIDGET_BG_START: Resource = $r('app.color.widget_bg_grad_start');
  readonly COLOR_WIDGET_BG_END: Resource = $r('app.color.widget_bg_grad_end');
  readonly COLOR_ITEM_BG: Resource = $r('app.color.widget_item_bg');

  readonly FONT_PRIMARY: Resource = $r('app.color.font_primary');
  readonly FONT_SECONDARY: Resource = $r('app.color.font_secondary');

  build() {
    Stack() {
      // 1. 背景层
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

      // 2. 内容层
      Column() {
        // --- 顶部栏 ---
        Row() {
          Image($r('app.media.icon'))
            .width(16) // [调整] 缩小图标以节省空间
            .height(16)
            .borderRadius(4)
            .margin({ right: 6 })

          Text("Deadliner")
            .fontSize(12) // [调整] 保持紧凑字体
            .fontWeight(FontWeight.Bold)
            .fontColor(this.FONT_PRIMARY)
            .layoutWeight(1)
            .maxLines(1)

          if (this.data.totalCount > 0) {
            Text(`${this.data.totalCount}`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.data.totalCount > 3 ? this.COLOR_ACCENT : this.COLOR_BRAND)
              .backgroundColor(this.COLOR_ITEM_BG)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(8)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 8 })

        // --- 任务列表 ---
        if (this.data.tasks.length === 0) {
          this.EmptyState()
        } else {
          List({ space: 3 }) {
            ForEach(this.data.tasks.slice(0, 3), (item: WidgetTaskItem) => {
              ListItem() {
                this.CompactTaskItem(item)
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
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
        .width(3) // [调整] 稍微变细一点点，显得精致
        .height(12)
        .backgroundColor(item.isUrgent ? this.COLOR_ACCENT : this.COLOR_BRAND)
        .borderRadius(1.5)
        .margin({ right: 6 })

      // 标题
      Text(item.title)
        .fontSize(12) // [调整] 字体改回 12，防止换行撑开高度
        .fontColor(this.FONT_PRIMARY)
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 时间
      Text(item.timeDesc)
        .fontSize(10)
        .fontColor(item.isUrgent ? this.COLOR_ACCENT : this.FONT_SECONDARY)
        .fontWeight(item.isUrgent ? FontWeight.Medium : FontWeight.Normal)
        .margin({ left: 4 })
        .maxLines(1)
        .flexShrink(0)
    }
    .width('100%')
    .height(32)
    .backgroundColor(this.COLOR_ITEM_BG)
    .borderRadius(8)
    .padding({ left: 6, right: 8 })
    .alignItems(VerticalAlign.Center)
    .border({
      width: item.isUrgent ? 1 : 0,
      color: this.COLOR_ACCENT
    })
  }

  @Builder
  EmptyState() {
    Column() {
      Text('🎉')
        .fontSize(28) // Emoji 可以稍微大一点，视觉上等于 24vp 的图标
        .opacity(0.8) // 稍微加一点透明度，不那么刺眼
        .margin({ bottom: 2 })

      Text("搞定！")
        .fontSize(12)
        .fontColor(this.FONT_SECONDARY)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}