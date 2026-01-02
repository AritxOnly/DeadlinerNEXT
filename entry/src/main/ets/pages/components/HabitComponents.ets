import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus } from '../../model/DDLModels';
import { ColorUtils } from '../../utils/ColorUtils';

// 接口定义保持不变
export interface DayOverview {
  date: Date;
  completedCount: number;
  totalCount: number;
  completionRatio: number;
}

export interface HabitWithDailyStatus {
  habit: Habit;
  doneCount: number;
  targetCount: number;
  isCompleted: boolean;
}

export enum DDLStatus {
  UNDERGO,
  NEAR,
  PASSED,
  COMPLETED
}

@Component
export struct HabitCircleProgress {
  @Prop progress: number;
  // 直接定义默认颜色
  private indicatorColor: ResourceColor = $r('app.color.brand');
  private bgColor: ResourceColor = $r('app.color.background_emphasize');

  build() {
    Stack({ alignContent: Alignment.Center }) {

      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Ring })
        .width(84)
        .height(84)
        .color(this.indicatorColor)
        .backgroundColor(this.bgColor)
        .style({ strokeWidth: 8 })
        .animation({ duration: 800, curve: Curve.Smooth })

      Text(`${(this.progress * 100).toFixed(0)}%`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
    }
  }
}

@Component
export struct WeekRow {
  @Prop weekOverview: DayOverview[];
  @Prop selectedDate: Date;
  onSelectDate: (d: Date) => void = () => {};

  // 颜色资源
  private primaryColor: ResourceColor = $r('app.color.brand');
  private bgColor: ResourceColor = $r('app.color.background_emphasize');
  private secondaryColor: ResourceColor = $r('app.color.font_secondary')
  private surfaceVariant: ResourceColor = $r('app.color.background_primary');

  private getDayLabel(date: Date): string {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.getDay()];
  }

  private isSameDay(d1: Date, d2: Date): boolean {
    return d1.getDate() === d2.getDate() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getFullYear() === d2.getFullYear();
  }

  build() {
    List({ space: 0, initialIndex: 0 }) {
      ForEach(this.weekOverview, (day: DayOverview) => {
        ListItem() {
          Column() {
            Text(this.getDayLabel(day.date))
              .fontSize(12)
              .fontColor(this.isSameDay(day.date, this.selectedDate) ? this.primaryColor : this.secondaryColor)
              .margin({ bottom: 4 })

            Column() {
              Text(day.date.getDate().toString())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.secondaryColor)
            }
            .justifyContent(FlexAlign.Center)
            .width(32)
            .height(32)
            .borderRadius(24)
            .backgroundColor(this.isSameDay(day.date, this.selectedDate) ? this.bgColor : Color.Transparent)

            if (day.completionRatio > 0) {
              Circle()
                .width(6)
                .height(6)
                .fill(this.primaryColor)
                .margin({ top: 4 })
            } else {
              Blank().height(6).margin({ top: 4 })
            }
          }
          .width(50)
          .onClick(() => this.onSelectDate(day.date))
        }
      })
    }
    .listDirection(Axis.Horizontal)
    // .width('100%')
    .height(80)
    .alignListItem(ListItemAlign.Center)
    .scrollBar(BarState.Off)
  }
}

@Component
struct HabitSelectionOverlay {
  @State primaryColor: ResourceColor = $r('app.color.brand'); // 默认值，实际会由 theme 覆盖
  @State containerColor: ResourceColor = $r('app.color.background_primary');
  @State onPrimaryColor: ResourceColor = Color.White;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 半透明遮罩背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.containerColor)
        .opacity(0.25)

      // 2. 边框
      Column()
        .width('100%')
        .height('100%')
        .border({
          width: 2,
          color: this.primaryColor,
          radius: 24 // 这里的 radius 要和卡片保持一致
        })
        .opacity(0.7)
        .hitTestBehavior(HitTestMode.Transparent)

      // 3. 左上角打钩
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor([this.onPrimaryColor])
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .backgroundColor(this.primaryColor)
      .shadow({ radius: 2 })
      .margin({ top: 8, left: 8 })
      .alignContent(Alignment.Center)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct HabitRow {
  @Prop data: HabitWithDailyStatus;
  @Prop status: DDLStatus;
  @Prop isSelected: boolean;
  @Prop canToggle: boolean;
  @Prop remainingText: string;

  onToggle: () => void = () => {};
  onLongPress: () => void = () => {};

  @State private titleColor: ResourceColor = $r('app.color.font_primary');
  @State private noteColor: ResourceColor = $r('app.color.font_secondary');

  // 颜色计算逻辑
  private getIndicatorColor(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.indicator_color_undergo');
      case DDLStatus.NEAR: return $r('app.color.indicator_color_near');
      case DDLStatus.PASSED: return $r('app.color.indicator_color_passed');
      case DDLStatus.COMPLETED: return $r('app.color.indicator_color_completed');
      default: return $r('app.color.indicator_color_undergo');
    }
  }

  private getBackgroundColor(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.background_color_undergo');
      case DDLStatus.NEAR: return $r('app.color.background_color_near');
      case DDLStatus.PASSED: return $r('app.color.background_color_passed');
      case DDLStatus.COMPLETED: return $r('app.color.background_color_completed');
      default: return $r('app.color.background_color_undergo');
    }
  }

  private getBottomLine(): string {
    let bottomLine = `${this.data.doneCount}/${this.data.targetCount}`;
    if (this.data.habit.goalType === HabitGoalType.TOTAL) {
      const total = this.data.habit.totalTarget ? this.data.habit.totalTarget : "∞";
      bottomLine = `${this.data.doneCount}/${total}`;
    }
    if (this.remainingText) {
      bottomLine = `${this.remainingText} · ${bottomLine}`;
    }
    return bottomLine;
  }

  private getRightLabel(): string {
    if (this.data.habit.goalType === HabitGoalType.PER_PERIOD) {
      return this.data.habit.period.toString();
    } else {
      return "Total";
    }
  }

  private getProgress(): number {
    return Math.min(1, Math.max(0, this.data.doneCount / Math.max(1, this.data.targetCount)));
  }

  private addAlpha(color: ResourceColor, alpha: number): string | ResourceColor {
    try {
      let context = this.getUIContext().getHostContext();
      return ColorUtils.addAlpha(color, alpha, context);
    } catch (e) {
      return color;
    }
  }

  build() {
    // 【修改点1】最外层 Stack 负责统一的圆角和裁剪
    Stack() {
      // 1. 内容层 (包括背景、进度条、文本)
      Stack({ alignContent: Alignment.Start }) {
        // 底色
        Rect()
          .width('100%')
          .height('100%')
          .fill(this.addAlpha(this.getBackgroundColor(), 0.3))

        // 进度条前景
        if (this.getProgress() > 0) {
          Row()
            .width(`${this.getProgress() * 100}%`)
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                [this.addAlpha(this.getIndicatorColor(), 0.4), 1.0],
                [this.addAlpha(this.getIndicatorColor(), 0.6), 0.0]
              ]
            })
            .animation({ duration: 800, curve: Curve.Smooth })
        }

        // 文本内容行
        Row() {
          Checkbox({ name: 'done', group: 'habit' })
            .select(this.data.isCompleted)
            .selectedColor(this.getIndicatorColor())
            .onChange(() => {
              if (this.canToggle) this.onToggle();
            })
            .enabled(this.canToggle)
            .margin({ right: 12 })

          Column() {
            Text(this.data.habit.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.titleColor)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)

            Text(this.getBottomLine())
              .fontSize(12)
              .fontColor(this.noteColor)
              .margin({ top: 4 })
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getRightLabel())
            .fontSize(10)
            .fontColor(this.noteColor)
        }
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .width('100%')
        .height(72)
      }
      .width('100%')
      .height(72)
      // 注意：这里不需要再设置 clip(true) 了，因为父容器会统一剪裁

      // 【修改点2】选中态遮罩层，放在最上层
      if (this.isSelected) {
        HabitSelectionOverlay()
      }
    }
    .width('100%')
    .height(72)
    .borderRadius(24) // 【修改点3】由最外层统一设置圆角
    .clip(true)       // 【修改点4】由最外层统一裁剪，消除锯齿
    .onClick(() => {
      if (this.canToggle) this.onToggle();
    })
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
  }
}