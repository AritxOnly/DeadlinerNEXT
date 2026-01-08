import { CapsuleWidgetData } from '../model/CapsuleWidgetData';

@Entry
@Component
struct LockScreenCapsule {
  @LocalStorageProp('widgetData') widgetData: CapsuleWidgetData = new CapsuleWidgetData();

  /**
   * 获取右侧辅助文字
   * 逻辑：
   * 1. 没任务 -> "无任务"
   * 2. 有任务 且 有临近 -> "X临近"
   * 3. 有任务 且 无临近 -> "待办"
   */
  getUnitText(): string {
    if (this.widgetData.remainingCount === 0) {
      return "无任务";
    } else if (this.widgetData.nearbyCount > 0) {
      return `临近${this.widgetData.nearbyCount}`;
    } else {
      return "待办";
    }
  }

  build() {
    // 外层容器：左右两端对齐
    Row() {

      // =========================
      // 左侧：数据展示区
      // =========================
      Row() {
        // 1. 大数字
        Text(this.widgetData.remainingCount.toString())
          .fontSize('32vp')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .lineHeight('32vp')
          .margin({ right: 4 })

        // 2. 动态辅助文字 (单位)
        Text(this.getUnitText())
          .fontSize('14vp') // 小字号
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .opacity(0.8) // 稍微半透明，拉开层次
          .margin({ bottom: 4 }) // 底部对齐微调
      }
      .alignItems(VerticalAlign.Bottom) // 底部基线对齐
      .onClick(() => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { target: 'main' }
        });
      })
      .margin({ bottom: -3 })

      // =========================
      // 中间：弹簧占位符
      // =========================
      Blank()

      // =========================
      // 右侧：纯色镂空加号按钮
      // =========================
      Stack() {
        // 1. 底层：半透明白色圆形
        Circle()
          .width('36vp')
          .height('36vp')
          .fill(Color.White)
          .opacity(0.8)

        // 2. 顶层：加号图标 (作为遮罩擦除底层)
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize('24vp')
          .fontWeight(FontWeight.Bold)
          .fontColor([Color.Black]) // 颜色随意，必须不透明
          .blendMode(BlendMode.DST_OUT, BlendApplyType.OFFSCREEN) // 镂空魔法
      }
      .width('36vp')
      .height('36vp')
      .onClick(() => {
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: { target: 'addTask' }
        });
      })

    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center) // 整体垂直居中
    .padding({ left: 14, right: 8 })
  }
}