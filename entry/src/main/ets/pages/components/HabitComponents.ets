import { SettingsConstants as C } from '../../common/local/SettingsConstants';
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

      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Eclipse })
        .width(84)
        .height(84)
        .color($r('app.color.brand_50'))
        // .backgroundColor(this.bgColor)
        // .style({ strokeWidth: 8 })
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
  // 数据源
  @Prop weekOverview: DayOverview[];
  @Prop selectedDate: Date;
  @Prop currentDate: Date = new Date();

  // 回调
  onSelectDate: (d: Date) => void = () => {};
  onChangeWeek: (offset: number) => void = () => {};

  @StorageProp(C.KEY_ENGLISH_SOMEWHERE)
  englishSomewhere: boolean = true;

  // 动画状态
  @State animOffset: number = 0; // X轴偏移量
  @State animOpacity: number = 1; // 透明度

  // 颜色定义
  private primaryColor: ResourceColor = $r('app.color.brand');
  private bgColor: ResourceColor = $r('app.color.brand_50');
  private secondaryColor: ResourceColor = $r('app.color.font_secondary');
  private primaryFontColor: ResourceColor = $r('app.color.font_primary');

  // --- 逻辑判断方法 ---
  private isSameDay(d1: Date, d2: Date): boolean {
    return d1.getDate() === d2.getDate() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getFullYear() === d2.getFullYear();
  }

  private getDayLabel(date: Date): string {
    const english = this.englishSomewhere;
    const days = english ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return days[date.getDay()];
  }

  private getDayLabelColor(date: Date): ResourceColor {
    return this.isSameDay(date, this.currentDate) ? this.primaryColor : this.secondaryColor;
  }

  private getDayLabelWeight(date: Date): FontWeight {
    return this.isSameDay(date, this.currentDate) ? FontWeight.Bold : FontWeight.Normal;
  }

  private getDateBgColor(date: Date): ResourceColor {
    return this.isSameDay(date, this.selectedDate) ? this.bgColor : Color.Transparent;
  }

  private getDateTextColor(date: Date): ResourceColor {
    const isToday = this.isSameDay(date, this.currentDate);
    const isSelected = this.isSameDay(date, this.selectedDate);
    if (isToday) return this.primaryColor;
    if (isSelected) return this.primaryFontColor;
    return this.secondaryColor;
  }

  private getDateFontWeight(date: Date): FontWeight {
    const isToday = this.isSameDay(date, this.currentDate);
    const isSelected = this.isSameDay(date, this.selectedDate);
    return (isToday || isSelected) ? FontWeight.Bold : FontWeight.Medium;
  }

  private getMonthTitle(): string[] {
    if (!this.weekOverview || this.weekOverview.length === 0) return ['', ''];
    const firstDay = this.weekOverview[0].date;
    return [`${firstDay.getFullYear()}`, `${firstDay.getMonth() + 1}`];
  }

  @Builder
  MonthTitle() {
    Row() {
      Text(this.getMonthTitle()[0])
        .fontSize('16vp')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryFontColor)
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })

      Text(' / ')
        .fontSize('16vp')
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand'))
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })

      Text(this.getMonthTitle()[1])
        .fontSize('16vp')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryFontColor)
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

  // --- 核心动画逻辑 ---

  /**
   * 执行切换动画
   * @param direction -1: 上一周(右滑), 1: 下一周(左滑)
   */
  private triggerSwitchAnimation(direction: number) {
    const screenWidth = 300;

    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.animOffset = direction === 1 ? -screenWidth : screenWidth;
      this.animOpacity = 0;
    });

    setTimeout(() => {
      this.onChangeWeek(direction);

      this.animOffset = direction === 1 ? screenWidth : -screenWidth;

      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.animOffset = 0;
        this.animOpacity = 1;
      });
    }, 200);
  }

  // --- UI 构建 ---

  @Builder
  DayItem(day: DayOverview) {
    Column() {
      Text(this.getDayLabel(day.date))
        .fontSize('12vp')
        .fontColor(this.getDayLabelColor(day.date))
        .fontWeight(this.getDayLabelWeight(day.date))
        .margin({ bottom: 4 })

      Column() {
        Text(day.date.getDate().toString())
          .fontSize('16vp')
          .fontWeight(this.getDateFontWeight(day.date))
          .fontColor(this.getDateTextColor(day.date))
      }
      .justifyContent(FlexAlign.Center)
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.getDateBgColor(day.date))

      if (day.completionRatio > 0) {
        Circle()
          .width(5)
          .height(5)
          .fill(this.primaryColor)
          .margin({ top: 4 })
      } else {
        Blank().height(5).margin({ top: 4 })
      }
    }
    .width('100%')
    .onClick(() => this.onSelectDate(day.date))
  }

  build() {
    Column() {
      // 顶部操作栏
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize('20vp')
            .fontColor([this.secondaryColor])
        }
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => this.triggerSwitchAnimation(-1))

        this.MonthTitle()

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize('20vp')
            .fontColor([this.secondaryColor])
        }
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => this.triggerSwitchAnimation(1))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Column() {
        List() {
          ForEach(this.weekOverview, (day: DayOverview) => {
            ListItem() {
              this.DayItem(day)
            }
            .width(`${100 / 7}%`)
          })
        }
        .listDirection(Axis.Horizontal)
        .width('100%')
        .height(56)
        .translate({ x: this.animOffset })
        .opacity(this.animOpacity)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event: GestureEvent) => {
              // 1. 跟随手指移动 (阻尼效果可选，这里直接跟随)
              this.animOffset = event.offsetX;
            })
            .onActionEnd((event: GestureEvent) => {
              const threshold = 60; // 触发切换的阈值距离

              if (event.offsetX < -threshold) {
                // 左滑距离足够 -> 下一周
                this.triggerSwitchAnimation(1);
              } else if (event.offsetX > threshold) {
                // 右滑距离足够 -> 上一周
                this.triggerSwitchAnimation(-1);
              } else {
                // 距离不够 -> 回弹复位
                animateTo({ duration: 300, curve: Curve.Rhythm }, () => {
                  this.animOffset = 0;
                });
              }
            })
        )
      }
      .width('100%')
      .clip(true)
    }
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

  // --- 1. 获取纯色 (用于 Checkbox 选中色) ---
  private getIndicatorColor(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.indicator_color_undergo');
      case DDLStatus.NEAR: return $r('app.color.indicator_color_near');
      case DDLStatus.PASSED: return $r('app.color.indicator_color_passed');
      case DDLStatus.COMPLETED: return $r('app.color.indicator_color_completed');
      default: return $r('app.color.indicator_color_undergo');
    }
  }

  // --- 2. 新增：获取 50% 透明度的主色 (用于渐变起色) ---
  private getIndicatorColor50(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.indicator_color_undergo_50');
      case DDLStatus.NEAR: return $r('app.color.indicator_color_near_50');
      case DDLStatus.PASSED: return $r('app.color.indicator_color_passed_50');
      case DDLStatus.COMPLETED: return $r('app.color.indicator_color_completed_50');
      default: return $r('app.color.indicator_color_undergo_50');
    }
  }

  // --- 3. 新增：获取 70% 透明度的主色 (用于渐变终色) ---
  private getIndicatorColor70(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.indicator_color_undergo_70');
      case DDLStatus.NEAR: return $r('app.color.indicator_color_near_70');
      case DDLStatus.PASSED: return $r('app.color.indicator_color_passed_70');
      case DDLStatus.COMPLETED: return $r('app.color.indicator_color_completed_70');
      default: return $r('app.color.indicator_color_undergo_70');
    }
  }

  // --- 4. 新增：获取 40% 透明度的背景色 (用于底色) ---
  private getBgColor40(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return $r('app.color.background_color_undergo_40');
      case DDLStatus.NEAR: return $r('app.color.background_color_near_40');
      case DDLStatus.PASSED: return $r('app.color.background_color_passed_40');
      case DDLStatus.COMPLETED: return $r('app.color.background_color_completed_40');
      default: return $r('app.color.background_color_undergo_40');
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

  // 【删除】 addAlpha 函数已不再需要

  build() {
    Stack() {
      // 1. 内容层
      Stack({ alignContent: Alignment.Start }) {
        // 底色：直接使用对应的资源 Getter
        Rect()
          .width('100%')
          .height('100%')
          .fill(this.getBgColor40())

        // 进度条前景
        if (this.getProgress() > 0) {
          Row()
            .width(`${this.getProgress() * 100}%`)
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                // 渐变色：直接使用对应的资源 Getter
                [this.getIndicatorColor50(), 0.0],
                [this.getIndicatorColor70(), 1.0]
              ]
            })
            .animation({ duration: 800, curve: Curve.Smooth })
        }

        // 文本内容行
        Row() {
          Checkbox({ name: 'done', group: 'habit' })
            .select(this.data.isCompleted)
            .selectedColor(this.getIndicatorColor()) // 选中色保持使用纯色
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

      // 选中态遮罩层
      if (this.isSelected) {
        HabitSelectionOverlay()
      }
    }
    .width('100%')
    .height(72)
    .borderRadius(24)
    .clip(true)
    .onClick(() => {
      if (this.canToggle) this.onToggle();
    })
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
  }
}