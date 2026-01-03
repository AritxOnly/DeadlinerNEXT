export class FloatUpModifier implements AttributeModifier<CommonAttribute> {
  private index: number = 0;
  private maxLoad: number = 15
  private enableAnimation: boolean = true

  constructor(index: number, maxLoad: number = 15, enable: boolean = true) {
    this.index = index;
    this.maxLoad = maxLoad
    this.enableAnimation = enable
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (this.enableAnimation) {
      instance.transition(
        TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 20 }))
          .animation({
            duration: 400,
            curve: Curve.FastOutSlowIn,
            delay: (this.index % this.maxLoad) * 50
          })
      );
    } else {

    }
  }
}