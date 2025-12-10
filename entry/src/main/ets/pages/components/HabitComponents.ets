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
  private bgColor: ResourceColor = $r('app.color.background_secondary');

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width(84)
        .height(84)
        .color(this.bgColor) // 背景色
        .style({ strokeWidth: 8 })

      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Ring })
        .width(84)
        .height(84)
        .color(this.indicatorColor)
        .style({ strokeWidth: 8 })
        .animation({ duration: 800, curve: Curve.Smooth })

      Text(`${(this.progress * 100).toFixed(0)}%`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.Black)
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
  private bgColor: ResourceColor = $r('app.color.background_secondary');
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
              .fontColor(this.isSameDay(day.date, this.selectedDate) ? this.primaryColor : Color.Gray)
              .margin({ bottom: 4 })

            Column() {
              Text(day.date.getDate().toString())
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.Gray)
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
    .width('100%')
    .height(80)
    .alignListItem(ListItemAlign.Center)
    .scrollBar(BarState.Off)
  }
}

@Component
export struct HabitRow {
  @ObjectLink data: HabitWithDailyStatus;
  @Prop status: DDLStatus;
  @Prop isSelected: boolean;
  @Prop canToggle: boolean;
  @Prop remainingText: string;

  onToggle: () => void = () => {};
  onLongPress: () => void = () => {};

  @State private titleColor: ResourceColor = $r('app.color.font_primary');
  @State private noteColor: ResourceColor = $r('app.color.font_secondary');

  // 1. 提取颜色计算逻辑到私有方法
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

  // 2. 提取文本计算逻辑
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

  // 辅助函数：添加透明度
  private addAlpha(color: ResourceColor, alpha: number): string | ResourceColor {
    try {
      let context = this.getUIContext().getHostContext();
      return ColorUtils.addAlpha(color, alpha, context);
    } catch (e) {
      return color;
    }
  }

  build() {
    Stack() {
      // 背景层
      Stack({ alignContent: Alignment.Start }) {
        // 底色 (调用方法)
        Rect()
          .width('100%')
          .height('100%')
          .fill(this.addAlpha(this.getBackgroundColor(), 0.3))

        // 进度条前景 (Gradient)
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
      }
      .width('100%')
      .height(72)
      .borderRadius(24)
      .clip(true)

      // 内容层
      Row() {
        Checkbox({ name: 'done', group: 'habit' })
          .select(this.data.isCompleted)
          .selectedColor(this.getIndicatorColor()) // 调用方法
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

          Text(this.getBottomLine()) // 调用方法
            .fontSize(12)
            .fontColor(this.noteColor)
            .margin({ top: 4 })
            .maxLines(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.getRightLabel()) // 调用方法
          .fontSize(10)
          .fontColor(this.noteColor)
      }
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .width('100%')
      .height(72)

      // 选中态遮罩
      if (this.isSelected) {
        Stack({ alignContent: Alignment.TopStart }) {
          // Mask
          Rect()
            .width('100%')
            .height('100%')
            .fill($r('app.color.background_primary'))
            .opacity(0.25)

          // Border
          Rect()
            .width('100%')
            .height('100%')
            .fillOpacity(0)
            .stroke($r('app.color.brand'))
            .strokeWidth(2)
            .radius(24)
            .opacity(0.7)
        }
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height(72)
    .borderRadius(24)
    .onClick(() => {
      if (this.canToggle) this.onToggle();
    })
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
  }
}