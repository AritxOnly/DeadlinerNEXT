import { common } from '@kit.AbilityKit';

@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController;
  context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  // [新增] 控制复选框选中状态
  @State isChecked: boolean = false;

  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
  onJumpToWeb: () => void = () => {};

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.security_shield'))
        .width(64)
        .height(64)
        .fontSize(64)
        .fontColor([$r('app.color.brand')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY)
        .margin({ top: 24, bottom: 8 })

      // 标题
      Text('服务协议与隐私政策')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 12 })

      // 富文本内容
      Text() {
        Span('欢迎使用 Deadliner待办日历！\n\n在使用本应用前，请您务必认真阅读并充分理解')
          .fontSize(16)
          .fontColor($r('app.color.font_primary'))

        // 可点击的链接部分
        Span('《隐私协议》')
          .fontSize(16)
          .fontColor($r('app.color.brand'))
          .fontWeight(FontWeight.Medium)
          .onClick(() => {
            this.controller.close();
            this.onJumpToWeb();
          })

        Span('。')
          .fontSize(16)
          .fontColor($r('app.color.font_primary'))
      }
      .margin({ left: 16, right: 16, bottom: 16 })
      .lineHeight(24)
      .textAlign(TextAlign.Center)

      // [新增] 复选框区域
      Row() {
        Checkbox({ name: 'privacy_checkbox' })
          .select(this.isChecked)
          .selectedColor($r('app.color.brand')) // 选中颜色跟随主题
          .width(20)
          .height(20)
          .margin({ right: 8 })
          .onChange((value: boolean) => {
            this.isChecked = value;
          })

        Text('我已阅读并同意隐私协议条款')
          .fontSize(14)
          .fontColor($r('app.color.font_primary'))
          .onClick(() => {
            // 体验优化：点击文字也能切换选中状态
            this.isChecked = !this.isChecked;
          })
      }
      .margin({ bottom: 24 }) // 与下方按钮的间距
      .justifyContent(FlexAlign.Center) // 整体居中
      .width('100%')

      // 按钮区域
      Row() {
        // 不同意按钮
        Button('不同意并退出')
          .fontColor($r('app.color.warning'))
          .backgroundColor(Color.Transparent) // 建议明确背景色，防止样式混淆
          .layoutWeight(1)
          .margin({ right: 12 })
          .onClick(() => {
            this.controller.close();
            this.onCancel();
          })

        // 同意/进入按钮
        Button('进入') // [修改] 按钮文字
          .fontColor(Color.White) // 建议：实心按钮通常文字为白色
          .backgroundColor($r('app.color.brand')) // 建议：实心按钮背景
          .layoutWeight(1)
          .margin({ left: 12 })
          // [新增] 状态控制
          .enabled(this.isChecked)
          .opacity(this.isChecked ? 1.0 : 0.4) // 未选中时变灰
          .onClick(() => {
            this.controller.close();
            this.onConfirm();
          })
      }
      .width('100%')
      .padding({ bottom: 16, left: 16, right: 16 })
    }
  }
}