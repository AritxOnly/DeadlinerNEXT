@Component
export struct OverviewPage {
  build() {
    Column() {
      Text("Overview Page")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    // .backgroundColor('#F1F3F5') // 浅灰色背景区分
  }
}

