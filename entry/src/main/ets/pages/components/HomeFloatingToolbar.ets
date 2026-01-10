import { HdsActionBar, ActionBarButton, ActionBarStyle, BlurStrategy } from '@kit.UIDesignKit'
import { ColorMetrics } from '@kit.ArkUI'

@Component
export struct HomeFloatingToolbar {
  @Require onClickAdd: () => void
  @Require handleBatchComplete: () => void
  @Require handleBatchArchive: () => void
  @Require handleBatchDelete: () => void
  @Require handleBatchEdit: () => void
  @Require handleSetAlarm: () => void

  @Prop isSelectionMode: boolean = false
  @Prop selectedTask: boolean = true;

  getLeftButton() {
    if (this.selectedTask) {
      return new ActionBarButton({
        baseIcon: $r('sys.symbol.checkmark_circle'),
        onClick: () => this.handleBatchComplete()
      })
    } else {
      return new ActionBarButton({
        baseIcon: $r('sys.symbol.alarm'),
        onClick: () => this.handleSetAlarm()
      })
    }
  }

  build() {
    HdsActionBar({
      startButtons: [
        this.getLeftButton(),
        // 2. 归档
        new ActionBarButton({
          baseIcon: $r('sys.symbol.archivebox'),
          onClick: () => this.handleBatchArchive()
        }),
      ],
      primaryButton: new ActionBarButton({
        baseIcon: $r('sys.symbol.plus'),
        altIcon: $r('sys.symbol.xmark'),
        backgroundColor: ColorMetrics.resourceColor($r('app.color.accent')),
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
      .hitTestBehavior(HitTestMode.Transparent)
  }
}