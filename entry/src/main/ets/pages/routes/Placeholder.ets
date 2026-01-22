@Builder
export function PlaceholderBuilder() {
  PlaceHolder();
}

@Component
export struct PlaceHolder {
  build() {
    Column() {
      Image($r('app.media.icon'))
        .size({ width: 60, height: 60 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_primary'))
  }
}