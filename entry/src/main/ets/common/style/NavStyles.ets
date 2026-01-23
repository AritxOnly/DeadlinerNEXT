import { LengthMetrics } from '@kit.ArkUI';
import { HdsNavigationTitleBarStyle, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';

/**
 * 获取统一的沉浸式标题栏样式配置
 * @param isWideScreen 是否为宽屏模式（宽屏下通常不需要模糊，而是纯色背景）
 * @returns HdsNavigationTitleBarStyle
 */
export function getImmersiveTitleBarStyle(isWideScreen: boolean): TitleBarStyleOptions {
  return {
    scrollEffectOpts: {
      // 宽屏模式下禁用滚动模糊特效（通常宽屏是分栏，右侧独立滚动，不需要顶栏模糊）
      enableScrollEffect: !isWideScreen,
      scrollEffectType: ScrollEffectType.COMMON_BLUR,
      blurEffectiveStartOffset: LengthMetrics.vp(0),
      blurEffectiveEndOffset: LengthMetrics.vp(10)
    },
    // --- 初始状态样式 (透明) ---
    // 手机端：全透明，让内容透上来实现沉浸
    // 平板端：使用背景色，因为分栏模式下通常不沉浸到状态栏
    originalStyle: {
      backgroundStyle: {
        backgroundColor: isWideScreen ?
          $r('app.color.background_primary') :
          $r('sys.color.ohos_id_color_background_transparent'),
      },
    },
    // --- 滚动生效后样式 (模糊/不透明) ---
    // 手机端：滚动后变成高斯模糊背景
    // 平板端：保持背景色
    scrollEffectStyle: {
      backgroundStyle: {
        backgroundColor: isWideScreen ?
          $r('app.color.background_primary') :
          $r('sys.color.ohos_id_color_navigation_background_blur'),
      },
    },
  };
}