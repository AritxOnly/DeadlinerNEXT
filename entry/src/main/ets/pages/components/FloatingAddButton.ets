import { HdsActionBar, ActionBarButton, ActionBarStyle, BlurStrategy } from '@kit.UIDesignKit'

@ComponentV2
export struct FloatingAddButton {
  @Param @Require onClickAdd: () => void
  @Local primaryHoverTips: ResourceStr = '添加'

  build() {
    HdsActionBar({
      primaryButton: new ActionBarButton({
        baseIcon: $r('sys.symbol.plus'),
        onClick: () => { this.onClickAdd() },
        hoverTips: this.primaryHoverTips
      }),
      actionBarStyle: new ActionBarStyle({
        backgroundBlurStyle: BlurStyle.Thin
      }),
      blurStrategy: BlurStrategy.ENABLE,
      isExpand: false
    })
  }
}