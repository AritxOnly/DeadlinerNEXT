export interface ThemePalette {
  primary: string;    // 主色 (品牌色)
  secondary: string;  // 次要色 (低饱和，用于容器/背景)
  tertiary: string;   // 第三色 (通常是补色或邻近色，用于强调)
}

export interface ColorSwatch {
  color: string;
  isLight: boolean; // 用于判断文字颜色应该是黑还是白
}

export class ColorGenerator {

  /**
   * 🎨 生成 [鲜艳/生动] 方案 (仿 Material 3 标准)
   * @param hue 色相 (0-360)
   */
  static generateVibrant(hue: number): ThemePalette {
    // 1. Primary: 高饱和，中等亮度 (M3标准 Tone=40~50)
    // 看起来深邃、专业，不是刺眼的荧光色
    const primary = ColorGenerator.hsvToHex(hue, 80, 80);

    // 2. Secondary: 同色相，但极低饱和度，高亮度 (用于背景容器)
    // M3 的 Secondary 通常是“带一点点主色调的灰”
    const secondary = ColorGenerator.hsvToHex(hue, 20, 95);

    // 3. Tertiary: 色相偏移 60度 (邻近色) 或 120度 (对比色)
    // M3 默认偏移 60 度，饱和度适中
    let tertiaryHue = (hue + 60) % 360;
    const tertiary = ColorGenerator.hsvToHex(tertiaryHue, 70, 85);

    return { primary, secondary, tertiary };
  }

  /**
   * 🌫️ 生成 [莫兰迪/经典] 方案 (低饱和，高级灰)
   * @param hue 色相 (0-360)
   */
  static generateMorandi(hue: number): ThemePalette {
    // 莫兰迪的核心：降低饱和度 (S)，并控制亮度 (V) 不太高也不太低，
    // 营造出一种“蒙了一层灰”的质感。

    // 1. Primary: 饱和度砍到 25% 左右，亮度降低，变得柔和
    const primary = ColorGenerator.hsvToHex(hue, 25, 75);

    // 2. Secondary: 饱和度极低 (10%)，亮度拉高，接近米白色/灰白色
    const secondary = ColorGenerator.hsvToHex(hue, 10, 92);

    // 3. Tertiary: 同样偏移色相，但饱和度也压低
    let tertiaryHue = (hue + 60) % 360;
    const tertiary = ColorGenerator.hsvToHex(tertiaryHue, 20, 80);

    return { primary, secondary, tertiary };
  }

  static generateSwatches(hue: number, type: 'morandi' | 'vibrant'): ColorSwatch[] {
    const swatches: ColorSwatch[] = [];
    const saturations = type === 'morandi' ? [20, 25, 30, 35, 40] : [60, 70, 80, 90, 100];
    const values = [85, 75, 65, 55, 45]; // 不同明度

    for (let i = 0; i < 5; i++) {
      swatches.push({
        color: ColorGenerator.hsvToHex(hue, saturations[i], values[i]),
        isLight: values[i] > 65 // 简单的亮度判断
      });
    }
    return swatches;
  }

  /**
   * 生成 9 个颜色，用于 Grid 展示
   * 包含：淡雅(Morandi)、标准(Standard)、浓郁(Deep)
   */
  static generateGradientSwatches(hue: number): ColorSwatch[] {
    const swatches: ColorSwatch[] = [];

    // 这里的参数你可以微调，凑够9个好看的颜色
    // 格式: [Saturation, Value]
    const configs = [
      [15, 95], [25, 90], [35, 85], // 第一行：非常浅/莫兰迪
      [50, 90], [60, 85], [70, 80], // 第二行：鲜艳/生动
      [70, 60], [80, 50], [90, 40]  // 第三行：深沉/专业
    ];

    for (let conf of configs) {
      swatches.push({
        color: ColorGenerator.hsvToHex(hue, conf[0], conf[1]),
        isLight: conf[1] > 65 // 亮度高则文字黑，反之白
      });
    }
    return swatches;
  }

  /**
   * HSV 转 Hex 辅助函数
   * @param h Hue 0-360
   * @param s Saturation 0-100
   * @param v Value 0-100
   */
  static hsvToHex(h: number, s: number, v: number): string {
    s /= 100;
    v /= 100;

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

    // 转 0-255 并转 Hex
    const toHex = (n: number) => {
      const hex = Math.round((n + m) * 255).toString(16);
      return hex.length === 1 ? '0' + hex : hex;
    };

    return `#FF${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase();
  }
}