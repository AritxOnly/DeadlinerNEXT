@CustomDialog
export struct OverviewSettingsDialog {
  controller: CustomDialogController;
  // 用于在 Slider 拖动时临时更新 UI显示
  @State tempMonthlyCount: number = 12;
  @State tempShowOverdue: boolean = true;

  @State buttonBgColor: ResourceColor = $r('app.color.brand')

  build() {
    Column() {
      Text("概览设置").fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })

      // 滑块区域
      Row() {
        Text("统计月数").layoutWeight(1)
        Text(`${this.tempMonthlyCount} 个月`).fontColor(Color.Gray)
      }.width('100%').margin({ bottom: 10 })

      Slider({
        value: this.tempMonthlyCount,
        min: 1,
        max: 12,
        step: 1,
        style: SliderStyle.OutSet
      })
        .showSteps(true)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.tempMonthlyCount = value;
        })

      Divider().margin({ top: 15, bottom: 15 })

      // 开关区域
      Row() {
        Column() {
          Text("显示逾期任务").fontSize(16)
          Text("在每日统计中包含逾期").fontSize(12).fontColor(Color.Gray)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.tempShowOverdue })
          .onChange((isOn: boolean) => {
            this.tempShowOverdue = isOn;
          })
      }.width('100%')

      // 按钮
      Row() {
        Button("确定")
          .onClick(() => {
            this.controller.close();
          })
          .width('100%')
          .backgroundColor(this.buttonBgColor)
      }.margin({ top: 30 })
    }
    .padding(16)
    .margin(16)
    .backgroundColor($r('app.color.background_primary'))
    .borderRadius(36)
  }
}