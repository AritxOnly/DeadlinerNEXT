import { uiMaterial } from '@kit.ArkUI';
import { Available, deviceInfo } from '@kit.BasicServicesKit';

export interface ImmersiveMaterialOptions {
  style?: uiMaterial.ImmersiveStyle;
  interactive?: boolean;
  lightEffect?: boolean;
  materialColor?: ResourceColor;
}

export function canUseSystemMaterial(): boolean {
  return deviceInfo.apiAvailable('26.0.0');
}

@Available({ minApiVersion: '26.0.0' })
export function buildImmersiveMaterial(options?: ImmersiveMaterialOptions): uiMaterial.Material {
  return new uiMaterial.ImmersiveMaterial({
    style: options?.style,
    interactive: options?.interactive,
    lightEffect: options?.lightEffect ? { color: undefined } : undefined,
    materialColor: options?.materialColor
  });
}

export class ImmersiveMaterialModifier implements AttributeModifier<CommonAttribute> {
  private options?: ImmersiveMaterialOptions;
  private enabled: boolean;

  constructor(options?: ImmersiveMaterialOptions, enabled: boolean = true) {
    this.options = options;
    this.enabled = enabled;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (!this.enabled || !canUseSystemMaterial()) {
      return;
    }

    instance.systemMaterial(buildImmersiveMaterial(this.options));
  }
}

export class MaterialPresets {
  static surface(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({ style: style, materialColor: color }, enabled);
  }

  static surfaceInteractive(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      materialColor: color
    }, enabled);
  }

  static surfaceGlow(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      lightEffect: true,
      materialColor: color
    }, enabled);
  }

  static buttonInteractive(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      materialColor: color
    }, enabled);
  }

  static buttonGlow(
    enabled: boolean = true,
    style?: uiMaterial.ImmersiveStyle,
    color?: ResourceColor
  ): ImmersiveMaterialModifier {
    return new ImmersiveMaterialModifier({
      style: style,
      interactive: true,
      lightEffect: true,
      materialColor: color
    }, enabled);
  }
}
