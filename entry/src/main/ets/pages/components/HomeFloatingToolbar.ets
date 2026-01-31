import { HdsActionBar, ActionBarButton, ActionBarStyle, BlurStrategy } from '@kit.UIDesignKit'
import { ColorMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { SettingsConstants as C } from '../../common/local/SettingsConstants'

@Component
export struct HomeFloatingToolbar {
  @Require onClickAdd: () => void
  @Require handleBatchComplete: () => void
  @Require handleBatchArchive: () => void
  @Require handleBatchDelete: () => void
  @Require handleBatchEdit: () => void
  @Require handleSetAlarm: () => void

  isHorizontal: boolean = true

  @Prop isSelectionMode: boolean = false
  @Prop selectedTask: boolean = true;

  @StorageLink(C.KEY_ADD_SYMBOL_WEIGHT) addSymbolWeight: number = 600;

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

  getIconButtonWeighed(res: Resource, weight: number) {
    return new SymbolGlyphModifier(res).fontWeight(weight)
  }

  build() {
    if (this.isHorizontal) {
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
          baseIconSymbolGlyphModifier: this.getIconButtonWeighed(
            $r('sys.symbol.plus'),
            this.addSymbolWeight
          ),
          altIconSymbolGlyphModifier: this.getIconButtonWeighed(
            $r('sys.symbol.xmark'),
            this.addSymbolWeight
          ),
          backgroundColor: ColorMetrics.resourceColor($r('app.color.accent')),
          onClick: () => {
            this.onClickAdd()
          }
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
          isPrimaryIconChanged: this.isSelectionMode,
        }),
        blurStrategy: BlurStrategy.ENABLE,
        isExpand: this.isSelectionMode
      })
        .hitTestBehavior(HitTestMode.Transparent)
    } else {
      HdsActionBar({
        startButtons: [
          this.getLeftButton(),
          // 2. 归档
          new ActionBarButton({
            baseIcon: $r('sys.symbol.archivebox'),
            onClick: () => this.handleBatchArchive()
          }),

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
        primaryButton: new ActionBarButton({
          baseIconSymbolGlyphModifier: this.getIconButtonWeighed(
            $r('sys.symbol.plus'),
            this.addSymbolWeight
          ),
          altIconSymbolGlyphModifier: this.getIconButtonWeighed(
            $r('sys.symbol.xmark'),
            this.addSymbolWeight
          ),
          backgroundColor: ColorMetrics.resourceColor($r('app.color.accent')),
          onClick: () => {
            this.onClickAdd()
          }
        }),
        actionBarStyle: new ActionBarStyle({
          backgroundBlurStyle: BlurStyle.Thick,
          isPrimaryIconChanged: this.isSelectionMode,
          isHorizontal: false
        }),
        blurStrategy: BlurStrategy.ENABLE,
        isExpand: this.isSelectionMode,
      })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}