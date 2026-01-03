export class TabAnimModifier implements AttributeModifier<CommonAttribute> {
  private tabIndex: number;
  private currentIndex: number;

  constructor(tabIndex: number, currentIndex: number) {
    this.tabIndex = tabIndex;
    this.currentIndex = currentIndex;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    const isSelected = (this.currentIndex === this.tabIndex);

    instance
    // 只负责设置目标值，不要在这里设置 animation
      .opacity(isSelected ? 1 : 0.0)
      .scale({
        x: isSelected ? 1 : 0.9,
        y: isSelected ? 1 : 0.9
      })
  }
}