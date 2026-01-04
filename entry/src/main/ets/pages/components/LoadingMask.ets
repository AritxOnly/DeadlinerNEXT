@Component
export struct LoadingMask {
  build() {
    Column() {
      LoadingProgress()
        .width(60)
        .height(60)

      Text('AI 正在分析...')
        .fontSize(16)
        .margin({ top: 10 })
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.container_modal_background'))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {})
    .zIndex(9999)
  }
}