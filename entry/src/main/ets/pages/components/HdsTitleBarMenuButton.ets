import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { BlurBackgroundModifier } from '../../utils/animation/BlurBackgroundModifier';
import { Symbol } from './infra/Symbol';
import { uiMaterial } from '@kit.ArkUI';
import { HarmonyOSCapabilities } from '../../common/platform/HarmonyOSCapabilities';

@Component
export struct HdsTitleBarMenuButton {
  @Prop icon: Resource = $r('sys.symbol.square');
  @Prop iconSize: number = 24;
  @Prop buttonSize: number = 40;
  @Prop barHeight: number = 52;

  isImage?: boolean

  @Prop isEnabled: boolean = true;
  @Require onButtonClick: () => void;

  @StorageProp('customBackgroundImage') customBg: string = '';
  @StorageProp(C.KEY_ENABLE_IMMERSIVE_MATERIAL) immersiveMaterial: boolean = false;
  @StorageLink(C.KEY_EXPERIMENTAL_COMPONENTS) experimentalComponents: boolean = true;

  private handleClick() {
    if (!this.isEnabled) {
      return;
    }
    this.onButtonClick();
  }

  @Builder
  private buttonIcon() {
    Symbol({
      icon: this.icon,
      isImage: this.isImage === true,
      fontSize: this.iconSize,
      fontColor: $r('sys.color.ohos_id_color_text_primary')
    })
  }

  build() {
    if (this.experimentalComponents && this.immersiveMaterial &&
      HarmonyOSCapabilities.isHarmonyOS7OrLater()) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.buttonIcon()
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .backgroundColor(Color.Transparent)
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
        lightEffect: {}
      }))
      .onClick(() => {
        this.handleClick();
      })
      .enabled(this.isEnabled)
    } else {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        this.buttonIcon()
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .attributeModifier(new BlurBackgroundModifier((!!this.customBg && this.immersiveMaterial),
        $r('sys.color.comp_background_tertiary')))
      .onClick(() => {
        this.handleClick();
      })
      .enabled(this.isEnabled)
    }
  }
}
