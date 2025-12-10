
@Component
export struct StatsCardContainer {
  @BuilderParam content: () => void;
  build() {
    Column() { this.content() }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(24)
    .clip(true)
  }
}