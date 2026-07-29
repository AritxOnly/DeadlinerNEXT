// utils/ColorGenerator.ts

export interface ColorSwatch {
  color: string;
  isLight: boolean; // 背景是否为亮色（决定文字用黑还是白）
}

export interface AccentOption {
  key: string;
  name: string;
  color: string;
}

export class ColorGenerator {

  /**
   * 生成品牌色
   * @param hue 色相 0-360
   * @param styleStrength 风格强度 0-100 (0=极度莫兰迪/灰，100=极度生动)
   */
  generateBrand(hue: number, styleStrength: number): ColorSwatch {
    // 算法微调：
    // 莫兰迪(Low Style): 低饱和(S:15-30)，中高明度(V:85-95) -> 柔和
    // 生动(High Style): 高饱和(S:70-90)，中等明度(V:80-90) -> 清晰

    // 线性插值计算 Saturation
    const minS = 35; const maxS = 90;
    const s = minS + (styleStrength / 100) * (maxS - minS);

    // 线性插值计算 Value (生动色通常稍微压一点亮度，显得不刺眼)
    const minV = 72; const maxV = 82;
    const v = minV + (styleStrength / 100) * (maxV - minV);

    const hex = this.hsvToHex(hue, s, v);

    // 简单判断亮度：S低V高通常是浅色
    const isLight = (v > 80 && s < 40);

    return { color: hex, isLight: isLight };
  }

  /**
   * 生成强调色方案策略 (严格模式：禁止浅色)
   */
  generateAccentStrategies(brandHue: number, brandSat: number): AccentOption[] {
    const strategies: AccentOption[] = [];

    // 1. 基础饱和度 (S)：Accent 通常比 Brand 更鲜艳一点
    // 但为了不发白，我们取 brandSat 和 60 的最大值，封顶 95
    const baseS = Math.min(Math.max(brandSat, 60), 95);

    // 2. 基础亮度 (V)：限制在深色区间，保证白字可见
    // 之前的 90 太亮了，改为 80 (或者跟 Brand 保持一致的逻辑)
    const baseV = 80;

    // 1. 同色系 (Monochromatic)
    strategies.push({
      key: 'mono', name: '同频',
      color: this.hsvToHex(brandHue, baseS, this.getSafeValue(brandHue, baseV))
    });

    // 2. 邻近色 (Analogous) - 偏移 30度
    const analogHue = (brandHue + 30) % 360;
    strategies.push({
      key: 'analog', name: '邻近',
      color: this.hsvToHex(analogHue, baseS, this.getSafeValue(analogHue, baseV))
    });

    // 3. 互补色 (Complementary) - 偏移 180度 (强对比)
    const compHue = (brandHue + 180) % 360;
    strategies.push({
      key: 'comp', name: '撞色',
      color: this.hsvToHex(compHue, baseS, this.getSafeValue(compHue, baseV))
    });

    // 4. 分裂互补 (Split) - 偏移 150度 (活跃)
    const splitHue = (brandHue + 150) % 360;
    strategies.push({
      key: 'split', name: '活跃',
      color: this.hsvToHex(splitHue, baseS, this.getSafeValue(splitHue, baseV))
    });

    return strategies;
  }

  hsvToHex(h: number, s: number, v: number): string {
    s /= 100; v /= 100;
    let c = v * s;
    let x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    let m = v - c;
    let r = 0, g = 0, b = 0;

    if (0 <= h && h < 60) { r = c; g = x; b = 0; }
    else if (60 <= h && h < 120) { r = x; g = c; b = 0; }
    else if (120 <= h && h < 180) { r = 0; g = c; b = x; }
    else if (180 <= h && h < 240) { r = 0; g = x; b = c; }
    else if (240 <= h && h < 300) { r = x; g = 0; b = c; }
    else if (300 <= h && h < 360) { r = c; g = 0; b = x; }

    return `#FF${this.channelToHex(r, m)}${this.channelToHex(g, m)}${this.channelToHex(b, m)}`.toUpperCase();
  }

  private getSafeValue(hue: number, baseValue: number): number {
    if ((hue > 40 && hue < 70) || (hue > 160 && hue < 190)) {
      return 65;
    }
    return baseValue;
  }

  private channelToHex(channel: number, offset: number): string {
    const hex = Math.round((channel + offset) * 255).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  }
}
