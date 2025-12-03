import { WidgetData, WidgetTaskItem } from '../model/WidgetData';

@Entry
@Component
struct TaskWidgetCardSmall {
  @LocalStorageProp('widgetData') data: WidgetData = new WidgetData();

  // 使用资源引用代替硬编码颜色，实现深浅色适配
  // 假设你在 color.json 中定义了 warning (红/橙) 和 brand (蓝/绿)
  readonly COLOR_URGENT: Resource = $r('app.color.warning');
  readonly COLOR_NORMAL: Resource = $r('app.color.brand');
  readonly ITEM_BG: Resource = $r('app.color.background_secondary');

  // 字体颜色资源
  readonly FONT_PRIMARY: Resource = $r('app.color.font_primary');
  readonly FONT_SECONDARY: Resource = $r('app.color.font_secondary');

  build() {
    Column() {
      // === 1. 迷你标题栏 ===
      Row() {
        Image($r('app.media.icon'))
          .width(18)
          .height(18)
          .borderRadius(4)
          .margin({ right: 6 }) // 增加间距

        // 新增：应用名称
        Text("Deadliner")
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.FONT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        if (this.data.totalCount > 0) {
          Text(`${this.data.totalCount}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.data.totalCount > 3 ? this.COLOR_URGENT : this.FONT_SECONDARY)
            .backgroundColor($r('app.color.background_secondary')) // 适配深色模式下的徽章背景
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
        }
      }
      .width('100%')
      .height(24)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 6 })

      // === 2. 紧凑列表 ===
      if (this.data.tasks.length === 0) {
        Column() {
          Text("没有更多的任务了")
            .fontSize(12)
            .fontColor(this.FONT_SECONDARY)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: 4 }) {
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
    // 移除纯色背景 backgroundColor
    // 添加线性渐变背景
    .linearGradient({
      angle: 190,
      colors: [
        [$r('app.color.background_primary'), 0.0],  // 起始色
        [$r('app.color.background_tertiary'), 1.0]  // 结束色 (稍微深一点/灰一点，形成质感)
      ]
    })
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
      // 左侧颜色条
      Column()
        .width(3)
        .height(14)
        .backgroundColor(item.isUrgent ? this.COLOR_URGENT : this.COLOR_NORMAL)
        .borderRadius(1.5)
        .margin({ right: 6 })

      // 标题
      Text(item.title)
        .fontSize(13)
        // 紧急时使用强调色，否则使用主字体色
        .fontColor(item.isUrgent ? this.COLOR_URGENT : this.FONT_PRIMARY)
        .fontWeight(item.isUrgent ? FontWeight.Bold : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 时间
      Text(item.timeDesc)
        .fontSize(10)
        .fontColor(item.isUrgent ? this.COLOR_URGENT : this.FONT_SECONDARY)
        .margin({ left: 4 })
        .maxLines(1)
        .flexShrink(0)
    }
    .width('100%')
    .height(30)
    .backgroundColor(this.ITEM_BG) // 使用资源背景色
    .borderRadius(8)
    .padding({ left: 6, right: 8 })
    .alignItems(VerticalAlign.Center)
  }
}