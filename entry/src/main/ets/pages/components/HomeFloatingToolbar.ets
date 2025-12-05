import { HdsActionBar, ActionBarButton, ActionBarStyle, BlurStrategy } from '@kit.UIDesignKit'

@Component
export struct HomeFloatingToolbar {
  @Require onClickAdd: () => void
  @Require handleBatchComplete: () => void
  @Require handleBatchArchive: () => void
  @Require handleBatchDelete: () => void
  @Require handleBatchEdit: () => void

  @Prop isSelectionMode: boolean = false

  build() {
    HdsActionBar({
      startButtons: [
        // 1. 标记完成
        new ActionBarButton({
          baseIcon: $r('sys.symbol.checkmark_circle'),
          onClick: () => this.handleBatchComplete()
        }),
        // 2. 归档
        new ActionBarButton({
          baseIcon: $r('sys.symbol.archivebox'),
          onClick: () => this.handleBatchArchive()
        }),
      ],
      primaryButton: new ActionBarButton({
        baseIcon: $r('sys.symbol.plus'),
        altIcon: $r('sys.symbol.xmark'),
        onClick: () => { this.onClickAdd() }
      }),
      endButtons: [
        new ActionBarButton({
          baseIcon: $r('sys.symbol.square_and_pencil'),
          onClick: () => this.handleBatchEdit()
        }),
        // 4. 删除
        new ActionBarButton({
          baseIcon: $r('sys.symbol.trash'),
          onClick: () => this.handleBatchDelete()
        }),
      ],
      actionBarStyle: new ActionBarStyle({
        backgroundBlurStyle: BlurStyle.Thick,
        isPrimaryIconChanged: this.isSelectionMode
      }),
      blurStrategy: BlurStrategy.ENABLE,
      isExpand: this.isSelectionMode
    })
  }
}