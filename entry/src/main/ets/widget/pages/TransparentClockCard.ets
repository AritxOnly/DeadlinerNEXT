import { HudWidgetData } from '../model/HudWidgetData'

@Entry
@Component
struct TransparentClockCard {
  @LocalStorageProp('hudData') data: HudWidgetData = new HudWidgetData();

  readonly COLOR_ACCENT: string = '#00ACC1';
  readonly COLOR_BRAND: string = '#80DEEA';
  @LocalStorageProp('textColor') textColor: string = '#FFFFFF';

  build() {
    Stack() {
      // 1. 背景透明

      // 2. 内容区域
      Column() {
        // --- 第一行：日期 & 临近任务 (保持不变) ---
        Row() {
          Text(this.data.dateStr)
            .fontSize(13)
            .fontColor(this.textColor)
            .opacity(0.9)
            .textShadow(this.getTextShadow())

          if (this.data.hasUrgent) {
            Text(' · ')
              .fontSize(13)
              .fontColor(this.textColor)
              .textShadow(this.getTextShadow())

            SymbolGlyph($r('sys.symbol.hourglass'))
              .fontSize(13)
              .fontColor([this.textColor])
              .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
              .margin({ right: 4 })

            Text(this.data.urgentTaskName)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.COLOR_BRAND)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .textShadow(this.getTextShadow())
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // --- 第二行：统计概览 (重点修复) ---
        Row() {
          if (this.data.hasUrgent) {
            Row({ space: 2 }) {
              Text(`${this.data.imminentCount}`) // 强制转字符串
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FF8A80')
                .textShadow(this.getTextShadow())

              Text('临近')
                .fontSize(12)
                .fontColor(this.textColor)
                .opacity(0.7)
                .textShadow(this.getTextShadow())
            }
            this.Divider()
          }

          // 2. 待办 (修复点：不要通过 StatItem 传参)
          Row({ space: 2 }) {
            Text(`${this.data.todoCount}`) // 这里直接读取 data，一定会刷新
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .textShadow(this.getTextShadow())

            Text('待办')
              .fontSize(12)
              .fontColor(this.textColor)
              .opacity(0.7)
              .textShadow(this.getTextShadow())
          }

          this.Divider()

          // 3. 习惯 (修复点：不要通过 StatItem 传参)
          Row({ space: 2 }) {
            Text(`${this.data.habitCount}`) // 这里直接读取 data，一定会刷新
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .textShadow(this.getTextShadow())

            Text('习惯')
              .fontSize(12)
              .fontColor(this.textColor)
              .opacity(0.7)
              .textShadow(this.getTextShadow())
          }
        }
        .width('100%')
        .margin({ top: 6 })

        // --- 第三行：时间 ---
        Blank()

        TextClock()
          .fontSize(76)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .textShadow(this.getTextShadow(true))
          .margin({ bottom: -10, left: -4 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(12)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Divider() {
    Text(' / ')
      .fontSize(10)
      .fontColor(this.textColor)
      .opacity(0.4)
      .margin({ left: 4, right: 4 })
  }

  getTextShadow(isStrong: boolean = false): ShadowOptions {
    return {
      radius: isStrong ? 4 : 2,
      color: 'rgba(0,0,0,0.35)',
      offsetX: 0,
      offsetY: 1
    };
  }
}