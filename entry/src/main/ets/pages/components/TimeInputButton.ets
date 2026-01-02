@Component
export struct TimeInputButton {
  // 定义显示的标题
  @Prop title: string = '';
  // 核心：使用 @Prop 接收格式化后的时间字符串
  // 当父组件算出新字符串传进来时，这里会自动刷新
  @Prop content: string = '';

  // 点击回调
  onClickButton: () => void = () => {};

  build() {
    Row() {
      Text(this.title)
        .fontSize(16)
        .fontColor($r('app.color.font_secondary'))

      Blank()

      Row() {
        Text(this.content)
          .fontSize(16)
          .fontColor($r('app.color.font_primary'))
          .fontWeight(FontWeight.Regular)
          .margin({ right: 8 })

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontColor([$r('app.color.font_secondary')])
          .fontSize(18)
      }
    }
    .width('100%')
    .height(56) // ITEM_HEIGHT
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.background_secondary')) // 保持一致的背景色
    .borderRadius(24) // COMMON_RADIUS
    .onClick(() => {
      this.onClickButton();
    })
  }
}