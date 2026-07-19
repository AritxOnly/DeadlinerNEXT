import { ITheme } from "../../common/theme/ThemeModel";
import { ImmersivePopupSurface } from "../../common/ui/ImmersivePopupSurface";

@CustomDialog
export struct AddDialogTablet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 控制器，用于关闭弹窗
  controller: CustomDialogController;

  // 回调函数
  onAddTask: () => void = () => {};
  onAddHabit: () => void = () => {};

  // 内部 Builder：封装选项卡片
  @Builder
  SelectionCard(title: string, symbol: Resource, color: ResourceColor, action: () => void) {
    Column() {
      // 图标区域
      SymbolGlyph(symbol)
        .fontSize(48) // 图标大小
        .fontColor([color]) // 图标颜色
        .renderingStrategy(SymbolRenderingStrategy.SINGLE) // 单色渲染
        .margin({ bottom: 12 })

      // 文字区域
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .width('100%')
    .height(120) // 固定高度，形成方形卡片感
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_list_card')) // 原生卡片背景色
    .borderRadius(16)
    // 点击交互
    .onClick(() => {
      this.controller.close(); // 先关闭弹窗
      action(); // 执行回调
    })
  }

  build() {
    Column() {
      ImmersivePopupSurface({ paddingValue: 24, radius: 36, fallbackBlurStyle: BlurStyle.Thick }) {
        Column() {
          Text('新建...')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ bottom: 20, top: 8, left: 4 })

          Row({ space: 16 }) {
            Column() {
              this.SelectionCard(
                '任务',
                $r('sys.symbol.list_checkmark'),
                this.theme.brand,
                this.onAddTask
              )
            }.layoutWeight(1)

            Column() {
              this.SelectionCard(
                '习惯',
                $r('sys.symbol.arrow_clockwise'),
                $r('app.color.chart_green'),
                this.onAddHabit
              )
            }.layoutWeight(1)
          }
          .width('100%')

          Button('取消')
            .width('100%')
            .margin({ top: 24 })
            .backgroundColor(Color.Transparent)
            .fontColor(this.theme.accent)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.controller.close();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
  }
}
