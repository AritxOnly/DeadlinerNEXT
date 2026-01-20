export class PressEffectModifier implements AttributeModifier<CommonAttribute> {
  private scale: number = 0.5

  constructor(scale?: number) {
    if (scale) this.scale = scale
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance.scale({ x: 1, y: 1 })
  }

  applyPressedAttribute(instance: CommonAttribute): void {
    instance.scale({ x: this.scale, y: this.scale })
  }
}