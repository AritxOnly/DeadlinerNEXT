import { DDLStatus } from "../../model/DDLStatus";
import { ColorUtils } from "../../utils/ColorUtils";

@Component
export struct DDLItemCardSimplified {
  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop status: DDLStatus = DDLStatus.UNDERGO;

  // 主题颜色状态
  @State private indicatorColor: ResourceColor = $r('app.color.indicator_color_undergo'); // 使用莫兰迪色系的颜色
  @State private bgColor: ResourceColor = $r('app.color.background_color_undergo'); // 使用莫兰迪色系的背景色
  @State private titleColor: ResourceColor = Color.Black;
  @State private noteColor: ResourceColor = Color.Gray;
  @State private globalBgColor: ResourceColor = $r('app.color.background_primary')

  // 模拟 onWillApplyTheme，实际项目中由系统或框架回调
  onWillApplyTheme(theme: Theme) {
    this.titleColor = theme.colors.fontPrimary;
    this.noteColor = theme.colors.fontSecondary;
    this.globalBgColor = theme.colors.backgroundPrimary

    // 根据 Status 映射颜色
    if (this.status === DDLStatus.UNDERGO) {
      // 使用主题颜色
      this.indicatorColor = $r('app.color.indicator_color_undergo');
      this.bgColor = $r('app.color.background_color_undergo');
    } else if (this.status === DDLStatus.NEAR) {
      // 使用莫兰迪色系：淡黄色
      this.indicatorColor = $r('app.color.indicator_color_near');
      this.bgColor = $r('app.color.background_color_near');
    } else if (this.status === DDLStatus.PASSED) {
      // 使用莫兰迪色系：浅棕色
      this.indicatorColor = $r('app.color.indicator_color_passed');
      this.bgColor = $r('app.color.background_color_passed');
    } else if (this.status === DDLStatus.COMPLETED) {
      // 使用莫兰迪色系：柔和绿色
      this.indicatorColor = $r('app.color.indicator_color_completed');
      this.bgColor = $r('app.color.background_color_completed');
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 背景进度条层
      Row() {
        // 进度部分
        if (this.progress > 0) {
          Row()
            .height('100%')
            .width(`${Math.max(0, Math.min(1, this.progress)) * 100}%`)
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                [this.addAlpha(this.indicatorColor, 0.4), 1.0],
                [this.addAlpha(this.indicatorColor, 0.6), 0.0]
              ]
            })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.addAlpha(this.bgColor, 0.3)) // 背景底色

      // 2. 内容层
      Column() {
        // 第一行：标题 + 时间 + 星标
        Row() {
          Text(this.title)
            .fontSize(20) // titleLarge
            .fontWeight(FontWeight.Bold)
            .fontColor(this.titleColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ right: 4 })

          Text(this.remainingTimeAlt)
            .fontSize(12) // bodySmall
            .fontColor(this.titleColor)
            .maxLines(1)
            .margin({ right: 8 })

          if (this.isStarred) {
            SymbolGlyph($r('sys.symbol.star_fill'))
              .fontSize(20)
              .fontColor([this.indicatorColor])
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        // 第二行：备注 (如果有)
        if (this.note && this.note.length > 0) {
          Text(this.note)
            .fontSize(12) // bodySmall
            .fontColor(this.noteColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(76)
    .borderRadius(24) // R.dimen.item_corner_radius
    .backgroundColor(this.globalBgColor)
    .clip(true)
  }

  // 辅助函数：简单的颜色透明度处理 (ArkTS中颜色处理通常需要具体工具类，这里简化处理)
  private addAlpha(color: ResourceColor, alpha: number): string | ResourceColor {
    let context = this.getUIContext().getHostContext()
    let alphaColor = ColorUtils.addAlpha(color, alpha, context);  // 使用 ColorUtils 中的 addAlpha 函数来处理透明度
    console.debug(`ColorUtils: alpha ${alpha} | alphaColor ${alphaColor}}`)
    return alphaColor
  }
}

@Component
struct SelectionOverlay {
  @State primaryColor: ResourceColor = Color.Blue;
  @State containerColor: ResourceColor = Color.White;
  @State onPrimaryColor: ResourceColor = Color.White;

  onWillApplyTheme(theme: Theme) {
    this.primaryColor = theme.colors.brand;
    this.containerColor = theme.colors.backgroundPrimary;
    this.onPrimaryColor = theme.colors.fontPrimary;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 半透明遮罩
      Rect()
        .width('100%')
        .height('100%')
        .fill(this.containerColor)
        .opacity(0.25)

      // 边框
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .stroke(this.primaryColor)
        .strokeWidth(2)
        .opacity(0.7)

      // 左上角打钩
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor([this.onPrimaryColor])
      }
      .width(24)
      .height(24)
      .borderRadius(20)
      .backgroundColor(this.primaryColor)
      .shadow({ radius: 2 })
      .margin(8)
      .alignContent(Alignment.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(24)
    .clip(true)
  }
}

@Component
export struct DDLItemCardSwipeable {
  // 数据 Props
  @Prop title: string;
  @Prop remainingTimeAlt: string;
  @Prop note: string;
  @Prop progress: number;
  @Prop isStarred: boolean;
  @Prop status: DDLStatus;

  // 交互 Props
  @Prop selectionMode: boolean = false;
  @Prop selected: boolean = false;

  // 回调
  onClickItem?: () => void;
  onComplete?: () => void;
  onDelete?: () => void;
  onLongPressSelect?: () => void;
  onToggleSelect?: () => void;

  // 内部状态
  @State offsetX: number = 0;
  @State cardWidth: number = 0;

  // 颜色状态
  @State deleteColor: ResourceColor = $r('app.color.chart_red'); // R.color.chart_red
  @State completeColor: ResourceColor = $r('app.color.chart_green'); // R.color.chart_green
  @State surfaceVariant: ResourceColor = $r('app.color.background_primary');
  @State fontColor: ResourceColor = $r('app.color.background_primary')

  build() {
    Stack() {
      // ==================
      // 1. 背景层 (滑动时露出)
      // ==================
      if (Math.abs(this.offsetX) > 0 && !this.selectionMode) {
        Stack() {
          // 根据滑动方向决定背景图标和颜色
          // 这里简化了颜色插值(lerp)，直接根据方向显示
          if (this.offsetX > 0) {
            // 向右滑 -> 完成 (StartToEnd)
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph($r('sys.symbol.checkmark'))
                  .fontSize(24) // 图标的实际大小
                  .fontColor([this.fontColor])
              }
              .width(48)
              .height(48)
              .borderRadius(24) // 容器的圆形形状
              .backgroundColor(this.completeColor)
              .shadow({ radius: 4, color: this.completeColor });
            }
            .width('100%')
            .height('100%')
            .padding({ left: 20 })
            .justifyContent(FlexAlign.Start)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(this.surfaceVariant)
          } else {
            // 向左滑 -> 删除 (EndToStart)
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                SymbolGlyph($r('sys.symbol.trash'))
                  .fontSize(24) // 图标的实际大小
                  .fontColor([this.fontColor])
              }
              .width(48)
              .height(48)
              .borderRadius(24) // 容器的圆形形状
              .backgroundColor(this.deleteColor)
              .shadow({ radius: 4, color: this.deleteColor });
            }
            .width('100%')
            .height('100%')
            .padding({ right: 20 })
            .justifyContent(FlexAlign.End)
            .alignItems(VerticalAlign.Center)
            .backgroundColor(this.surfaceVariant)
          }
        }
        .width('100%')
        .height(76)
        .borderRadius(24)
        .clip(true)
      }

      // ==================
      // 2. 前景卡片层
      // ==================
      Stack() {
        DDLItemCardSimplified({
          title: this.title,
          remainingTimeAlt: this.remainingTimeAlt,
          note: this.note,
          progress: this.progress,
          isStarred: this.isStarred,
          status: this.status
        })

        // 选择态覆盖层
        if (this.selectionMode && this.selected) {
          SelectionOverlay()
        }
      }
      .translate({ x: this.offsetX }) // 核心位移
      .onAreaChange((oldArea, newArea) => {
        this.cardWidth = newArea.width as number;
      })
      // 手势处理
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          // 1. 长按手势
          LongPressGesture()
            .onAction(() => {
              if (this.onLongPressSelect) {
                this.onLongPressSelect();
              }
            }),

          // 2. 拖动手势 (仅在非选择模式下启用)
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event) => {
              if (this.selectionMode) return;
              this.offsetX = event.offsetX;
            })
            .onActionEnd(() => {
              if (this.selectionMode) return;

              const threshold = this.cardWidth * 0.4; // 滑动超过 40% 触发

              if (this.offsetX > threshold) {
                // 触发完成
                if (this.onComplete) this.onComplete();
                // 动画回弹或保持(取决于你的业务逻辑，这里模拟 Compose 的回弹)
                this.resetSwipe();
              } else if (this.offsetX < -threshold) {
                // 触发删除
                if (this.onDelete) this.onDelete();
                this.resetSwipe();
              } else {
                // 未达到阈值，回弹
                this.resetSwipe();
              }
            }),

          // 3. 点击手势
          TapGesture()
            .onAction(() => {
              if (this.selectionMode) {
                if (this.onToggleSelect) this.onToggleSelect();
              } else {
                if (this.onClickItem) this.onClickItem();
              }
            })
        )
      )
    }
    .width('100%')
    .height(76)
  }

  private resetSwipe() {
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.offsetX = 0;
    })
  }
}