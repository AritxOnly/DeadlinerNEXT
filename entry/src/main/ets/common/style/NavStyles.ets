import { LengthMetrics } from '@kit.ArkUI';
import { hdsMaterial, HdsNavigationTitleBarStyle, ScrollEffectType, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { ThemeManager } from '../theme/ThemeManager';
import { deviceInfo } from '@kit.BasicServicesKit';
import { MATERIAL_LEVEL } from './config';
import { LocalValues } from '../local/LocalValues';

/**
 * 获取统一的沉浸式标题栏样式配置
 * @param isWideScreen 是否为宽屏模式（宽屏下通常不需要模糊，而是纯色背景）
 * @returns HdsNavigationTitleBarStyle
 */
export function getImmersiveTitleBarStyle(isWideScreen: boolean) : TitleBarStyleOptions {
  if (deviceInfo.distributionOSApiVersion >= 60100 && LocalValues.getInstance().getApi23Enable()) {
    return {
      scrollEffectOpts: {
        enableScrollEffect: !isWideScreen,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(10),
      },
      originalStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_background_transparent'),
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.font_primary'), subTitleColor: $r('app.color.font_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.font_primary'), },
          subIconStyle: { iconColor: $r('app.color.font_primary'), },
          menuStyle: { iconColor: $r('app.color.font_primary') }
        }
      },
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_navigation_background_blur'),
          blurRadius: 32
        },
        contentStyle: {
          titleStyle: {
            mainTitleColor: $r('app.color.font_primary'), subTitleColor: $r('app.color.font_secondary')
          },
          backIconStyle: { iconColor: $r('app.color.font_primary'), },
          subIconStyle: { iconColor: $r('app.color.font_primary'), },
          menuStyle: { iconColor: $r('app.color.font_primary') }
        }
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: MATERIAL_LEVEL
      },
    };
  } else {
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
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_background_transparent'),
        },
      },
      // --- 滚动生效后样式 (模糊/不透明) ---
      // 手机端：滚动后变成高斯模糊背景
      // 平板端：保持背景色
      scrollEffectStyle: {
        backgroundStyle: {
          backgroundColor: isWideScreen ?
            ThemeManager.getCurrentTheme().bgPrimary :
            $r('sys.color.ohos_id_color_navigation_background_blur'),
        },
      },
    };
  }
}