@Component
export struct UserPage {
  build() {
    Column() {
      Text("User Profile")
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F1F3F5')
  }
}