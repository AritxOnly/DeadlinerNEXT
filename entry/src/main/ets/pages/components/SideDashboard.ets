import { Theme } from '@kit.ArkUI'

@Component
export struct SideDashboard {
  @State currentDate: Date = new Date();
  @Prop todayProgress: number = 65; // 今日任务完成度

  // 模拟数据
  @State nextDeadlineTime: string = "2h 15m";
  @State nextDeadlineTask: string = "交互设计";

  // 配色变量
  @State colorMonth: ResourceColor = $r('app.color.accent')
  @State colorDay: ResourceColor = $r('app.color.font_primary')
  @State colorWeek: ResourceColor = $r('app.color.font_secondary')

  @State colorRing: ResourceColor = $r('app.color.brand')
  @State colorYearBar: ResourceColor = $r('app.color.func_manual')
  @State colorNextDue: ResourceColor = $r('app.color.chart_red')

  @State cardBg: ResourceColor = $r('app.color.background_secondary')
  @State dashboardBg: ResourceColor = $r('app.color.background_primary')

  onWillApplyTheme(theme: Theme) {
    // 这里可以根据系统深色模式微调，但目前直接引用 resource 即可自动适配
  }

  // 计算今年的进度 (0-100)
  getYearProgress(): number {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    const progress = (now.getTime() - start.getTime()) / (end.getTime() - start.getTime());
    return Math.round(progress * 100);
  }

  build() {
    Column() {
      // 1. 日历撕页
      Column() {
        Text(this.currentDate.toLocaleString('en-US', { month: 'short' }).toUpperCase())
          .fontSize(16)
          .fontColor(this.colorMonth) // Accent Color
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 2 })

        Text(this.currentDate.getDate().toString())
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorDay)
          .height(46)

        Text(this.currentDate.toLocaleString('en-US', { weekday: 'short' }))
          .fontSize(14)
          .fontColor(this.colorWeek)
          .margin({ top: 4 })
      }
      .margin({ top: 32, bottom: 32 })

      // 2. 今日任务完成度
      Stack() {
        // 背景轨
        Progress({ value: 100, total: 100, type: ProgressType.Ring })
          .width(64)
          .height(64)
          .color($r('app.color.background_emphasize')) // 浅灰色底轨
          .style({ strokeWidth: 8 })

        // 进度轨
        Progress({ value: this.todayProgress, total: 100, type: ProgressType.Ring })
          .width(64)
          .height(64)
          .color(this.colorRing) // Brand Blue
          .style({ strokeWidth: 8 })

        Column() {
          Text(`${this.todayProgress}%`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorDay)
        }
      }
      .margin({ bottom: 40 })

      // 3. 宏观时间进度 (Year Progress)
      Column() {
        Row() {
          Text('2026')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colorWeek)
            .opacity(0.8)

          Text(`${this.getYearProgress()}%`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorYearBar) // 使用青色文字呼应进度条
        }
        .width('70%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 6 })

        Progress({ value: this.getYearProgress(), total: 100, type: ProgressType.Linear })
          .width('70%')
          .height(6)
          .color(this.colorYearBar) // Func Manual (Teal/Green)
          .backgroundColor($r('app.color.background_emphasize'))
          .style({ strokeRadius: 3 })
      }
      .margin({ bottom: 40 })


      // 4. 最近的危机 (Next DDL)
      // 使用胶囊卡片，背景白色，内容红色
      Column() {
        Text('NEXT DUE')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colorWeek)
          .margin({ bottom: 8 })
          .opacity(0.6)
          .letterSpacing(1)

        Column() {
          // 沙漏图标
          SymbolGlyph($r('sys.symbol.hourglass'))
            .fontSize(24)
            .fontColor([this.colorNextDue]) // Chart Red
            .margin({ bottom: 8 })

          // 时间
          Text(this.nextDeadlineTime)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorDay)

          // 任务名
          Text(this.nextDeadlineTask)
            .fontSize(10)
            .fontColor(this.colorWeek)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
            .opacity(0.8)
        }
        .padding({ top: 16, bottom: 16, left: 8, right: 8 })
        .backgroundColor(this.cardBg) // White Background
        .borderRadius(16)
        .width('85%')
        .shadow({ radius: 20, color: '#1A000000', offsetY: 4 }) // 极轻的阴影增加立体感
      }
    }
    .width('100%')
    .height('100%')
    .opacity(1)
  }
}