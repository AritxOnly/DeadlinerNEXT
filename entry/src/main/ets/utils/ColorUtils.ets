import { Context } from '@kit.AbilityKit';

export class ColorUtils {
  /**
   * 简单的透明度处理函数，接受一个颜色和透明度值，并返回带透明度的颜色。
   * @param color - 原始颜色（支持十六进制色值）
   * @param alpha - 透明度，范围从 0（完全透明）到 1（完全不透明）
   * @returns 带透明度的颜色
   */
  static addAlpha(color: ResourceColor, alpha: number, ctx: Context | undefined = undefined): ResourceColor | string {
    // 如果颜色是十六进制格式 (#RRGGBB)，则增加透明度
    if (typeof color === 'string' && color.startsWith('#') && color.length === 7) {
      // 从 #RRGGBB 获取 R、G、B 值
      let r = parseInt(color.substring(1, 3), 16);
      let g = parseInt(color.substring(3, 5), 16);
      let b = parseInt(color.substring(5, 7), 16);

      // 将透明度（alpha）值转换为 2 位十六进制字符串
      let a = Math.round(alpha * 255).toString(16).padStart(2, '0');

      // 返回带透明度的颜色（#RRGGBBAA）
      return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}${a}`;
    } else if (ctx) {
      return ColorUtils.applyAlpha(ctx, color, alpha)
    }

    // 如果颜色已经是 ResourceColor 类型，直接返回
    return color;
  }

  /**
   * 给 ResourceColor 添加透明度
   * @param context 组件上下文 (getContext(this))
   * @param color 颜色 (Resource, Color, string, number)
   * @param alpha 透明度 0.0 - 1.0
   * @returns rgba 字符串，可直接用于属性赋值
   */
  static applyAlpha(context: Context, color: ResourceColor, alpha: number): string {
    let colorValue: number;

    try {
      if (typeof color === 'object' &&  (color as Resource).id) {
        // 1. 如果是 Resource ($r)，使用 ResourceManager 解析
        // 注意：getColorSync 返回的是十进制整数 (通常是 AARRGGBB 或 RRGGBB)
        const resourceManager = context.resourceManager;
        colorValue = resourceManager.getColorSync(color as Resource);
      } else if (typeof color === 'number') {
        // 2. 如果是 Color 枚举或 Hex 数字
        colorValue = color;
      } else if (typeof color === 'string') {
        // 3. 如果是字符串，建议直接返回 rgba 拼接 (简单处理 hex 字符串)
        // 这里为了简化逻辑，暂不处理复杂的颜色名解析，建议主要使用 Resource 或 Hex
        return color; // 字符串处理比较复杂，建议优先用 Resource
      } else {
        const resourceManager = context.resourceManager;
        colorValue = resourceManager.getColorSync($r('app.color.background_primary'));
      }

      // 解析 ARGB / RGB
      // 鸿蒙 getColorSync 返回的一般是带 Alpha 的整数，我们需要提取 RGB 重新组合
      const r = (colorValue >> 16) & 0xFF;
      const g = (colorValue >> 8) & 0xFF;
      const b = colorValue & 0xFF;

      // 使用 CSS 样式的 rgba 语法，ArkTS 支持这种写法
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;

    } catch (e) {
      console.error('ColorUtils parse error:', e);
      return '#000000'; // 失败回退
    }
  }
}