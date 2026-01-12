@CustomDialog
export struct HabitReminderDialog {
  controller: CustomDialogController;
  habitName: string = "";

  @State isEnabled: boolean = false;
  // 初始时间
  @State selectedTime: Date = new Date();

  onConfirm: (enabled: boolean, timeStr: string) => void = () => {};

  build() {
    Column() {
      // 1. 标题区域
      Text(`提醒设置: ${this.habitName}`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 8, bottom: 24 })

      // 2. 开关区域
      Row() {
        Column() {
          Text("每日打卡提醒")
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))

          Text(this.isEnabled ? "将在指定时间发送通知" : "提醒已关闭")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
          .selectedColor($r('app.color.brand'))
          .onChange((isOn) => {
            animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
              this.isEnabled = isOn;
            })
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      // 3. 内嵌时间选择器 (无日期标题，纯净滚轮)
      // 使用显隐控制，当开启时展示
      if (this.isEnabled) {
        Column() {
          TimePicker({
            selected: this.selectedTime,
          })
            .useMilitaryTime(true) // 24小时制
            .textStyle({ color: $r('sys.color.ohos_id_color_text_secondary'), font: { size: '14fp', weight: FontWeight.Normal } })
            .selectedTextStyle({ color: $r('app.color.brand'), font: { size: '18fp', weight: FontWeight.Bold } })
            .onChange((value: TimePickerResult) => {
              // 实时更新时间
              const newDate = new Date();
              newDate.setHours(value.hour, value.minute);
              this.selectedTime = newDate;
            })
            .margin({ top: 16 })
        }
        .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
      }

      // 4. 底部按钮区域
      Row() {
        Button("取消")
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onClick(() => {
            this.controller.close();
          })

        Divider().vertical(true).height(24).color($r('sys.color.ohos_id_color_list_separator'))

        Button("保存")
          .fontColor($r('app.color.brand'))
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onClick(() => {
            const timeStr = this.formatTime(this.selectedTime);
            this.onConfirm(this.isEnabled, timeStr);
            this.controller.close();
          })
      }
      .margin({ top: 24 })
      .width('100%')
    }
    .padding(16)
    .margin(16)
    .borderRadius(36)
    .backgroundBlurStyle(BlurStyle.Thick)
  }

  private formatTime(date: Date): string {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
}