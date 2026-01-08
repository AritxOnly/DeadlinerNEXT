import { CapsuleWidgetData } from '../model/CapsuleWidgetData';

@Entry
@Component
struct TaskWidgetCardCapsule {
  @LocalStorageProp('widgetData') widgetData: CapsuleWidgetData = new CapsuleWidgetData();

  build() {
    Stack({ alignContent: Alignment.Center }) {

      // ===============================================
      // Layer 1: 背景装饰层
      // ===============================================
      Stack() {
        // 1.1 渐变底色
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            direction: GradientDirection.RightBottom,
            colors: [
              [$r('app.color.widget_bg_grad_start'), 0.0],
              [$r('app.color.widget_bg_grad_end'), 1.0]
            ]
          })

        // 1.2 波纹调整
        Circle()
          .width(140)
          .height(140)
          .fill($r('app.color.brand'))
          .opacity(0.05)
          .position({ x: '60%', y: '-15%' })

        Circle()
          .width(90)
          .height(90)
          .fill($r('app.color.brand'))
          .opacity(0.08)
          .position({ x: '75%', y: '10%' })

        // 1.3 小红点装饰
        if (this.widgetData.remainingCount > 0) {
          Circle()
            .width(10)
            .height(10)
            .fill($r('app.color.accent'))
            .opacity(0.8)
            .position({ x: '90%', y: '15%' })
        }
      }
      .width('100%')
      .height('100%')
      .borderRadius(16)
      .clip(true)
      .backgroundColor($r('app.color.background_secondary'))

      Row() {
        // --- 左侧：文本信息块 ---
        Column() {
          Text(this.widgetData.summary)
            .fontSize('14vp')
            .fontWeight(FontWeight.Bold)
            .fontColor(this.widgetData.remainingCount > 0 ? $r('app.color.font_primary') : $r('app.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          // 2. 底部鼓励语
          if (this.widgetData.remainingCount > 0) {
            Text('Keep going')
              .fontSize('11vp')
              .fontColor($r('app.color.brand_50'))
              .margin({ top: 4 }) // 稍微拉开一点间距，平衡去掉了顶部文字后的空旷感
          }
        }
        .alignItems(HorizontalAlign.Start) // 左对齐
        .justifyContent(FlexAlign.Center) // 垂直居中
        .layoutWeight(1) // 占据左侧所有剩余空间
        .height('100%')

        // --- 右侧：大数字展示 ---
        Column() {
          if (this.widgetData.remainingCount > 0) {
            // 显示大数字
            Text(this.widgetData.remainingCount.toString())
              .fontSize('40vp') // 使用 vp，并加大到 40，填补视觉空间
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand'))
              // 【关键】lineHeight 也必须用 vp，否则系统调整字体时行高会变，导致数字被切
              .lineHeight('40vp')
              .textAlign(TextAlign.End)
          } else {
            // 显示完成图标
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize('32vp') // 使用 vp
              .fontColor([$r('app.color.confirm')])
          }
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.End)
        .padding({ left: 4 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 16, top: 10, bottom: 10 })
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
}