import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem, uiMaterial } from '@kit.ArkUI';
import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { HarmonyOSCapabilities } from '../../common/platform/HarmonyOSCapabilities';

@Component
export struct HdsTitleBarSegment {
  @Require buttons: ItemRestriction<SegmentButtonTextItem>;
  @Link selectedIndexes: number[];

  @Prop maxFontScale: number = 2;
  @Prop segmentHeight: number = 48;
  @Prop normalWidth: Length = '100%';
  @Prop experimentalWidth: Length = '100%';
  @Prop experimentalHeight: number = 52;

  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = true;
  @StorageProp(C.KEY_ENABLE_IMMERSIVE_MATERIAL) immersiveMaterial: boolean = false;
  @StorageProp('customBackgroundImage') customBg: string = '';

  private buildDefaultOptions(): SegmentButtonOptions {
    return SegmentButtonOptions.tab({
      buttons: this.buttons,
      backgroundBlurStyle: (!!this.customBg && this.immersiveMaterial) ? BlurStyle.Thin : BlurStyle.NONE,
      selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
      backgroundColor: $r('sys.color.comp_background_tertiary'),
      buttonPadding: 10
    });
  }

  private buildExperimentalOptions(): SegmentButtonOptions {
    return SegmentButtonOptions.tab({
      buttons: this.buttons,
      backgroundBlurStyle: BlurStyle.NONE,
      selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
      backgroundColor: Color.Transparent,
      backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        colorInvert: true,
        applyShadow: true,
        interactive: false,
        lightEffect: {}
      }),
      buttonPadding: 10
    });
  }

  @Builder
  private segmentContent(options: SegmentButtonOptions) {
    SegmentButton({
      options: options,
      selectedIndexes: $selectedIndexes,
      maxFontScale: this.maxFontScale
    })
      .width('100%')
      .height(this.segmentHeight)
  }

  build() {
    if (this.experimentalComponents && this.immersiveMaterial &&
      HarmonyOSCapabilities.isHarmonyOS7OrLater()) {
      Stack({ alignContent: Alignment.Center }) {
        this.segmentContent(this.buildExperimentalOptions())
      }
      .width(this.experimentalWidth)
      .height(this.experimentalHeight)
      .margin({ top: -8 })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        this.segmentContent(this.buildDefaultOptions())
      }
      .width(this.normalWidth)
      .height(this.segmentHeight)
    }
  }
}
