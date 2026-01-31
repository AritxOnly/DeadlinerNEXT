export interface ITheme {
  brand: ResourceColor;
  brand50: ResourceColor;
  accent: ResourceColor;
  bgPrimary: ResourceColor;

  indicatorUndergo: ResourceColor;
  indicatorUndergo50: ResourceColor;
  indicatorUndergo70: ResourceColor;
  bgUndergo: ResourceColor;
  bgUndergo40: ResourceColor;

  indicatorNear: ResourceColor;
  indicatorNear50: ResourceColor;
  indicatorNear70: ResourceColor;
  bgNear: ResourceColor;
  bgNear40: ResourceColor;

  indicatorPassed: ResourceColor;
  indicatorPassed50: ResourceColor;
  indicatorPassed70: ResourceColor;
  bgPassed: ResourceColor;
  bgPassed40: ResourceColor;

  indicatorCompleted: ResourceColor;
  indicatorCompleted50: ResourceColor;
  indicatorCompleted70: ResourceColor;
  bgCompleted: ResourceColor;
  bgCompleted40: ResourceColor;
}

interface IndicatorSet {
  indicatorUndergo: Resource;
  indicatorUndergo50: Resource;
  indicatorUndergo70: Resource;
  bgUndergo: Resource;
  bgUndergo40: Resource;
  indicatorNear: Resource;
  indicatorNear50: Resource;
  indicatorNear70: Resource;
  bgNear: Resource;
  bgNear40: Resource;
  indicatorPassed: Resource;
  indicatorPassed50: Resource;
  indicatorPassed70: Resource;
  bgPassed: Resource;
  bgPassed40: Resource;
  indicatorCompleted: Resource;
  indicatorCompleted50: Resource;
  indicatorCompleted70: Resource;
  bgCompleted: Resource;
  bgCompleted40: Resource;
}

const INDICATORS_MORANDI: IndicatorSet = {
  indicatorUndergo: $r('app.color.indicator_morandi_undergo'),
  indicatorUndergo50: $r('app.color.indicator_morandi_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_morandi_undergo_70'),
  bgUndergo: $r('app.color.bg_morandi_undergo'),
  bgUndergo40: $r('app.color.bg_morandi_undergo_40'),

  indicatorNear: $r('app.color.indicator_morandi_near'),
  indicatorNear50: $r('app.color.indicator_morandi_near_50'),
  indicatorNear70: $r('app.color.indicator_morandi_near_70'),
  bgNear: $r('app.color.bg_morandi_near'),
  bgNear40: $r('app.color.bg_morandi_near_40'),

  indicatorPassed: $r('app.color.indicator_morandi_passed'),
  indicatorPassed50: $r('app.color.indicator_morandi_passed_50'),
  indicatorPassed70: $r('app.color.indicator_morandi_passed_70'),
  bgPassed: $r('app.color.bg_morandi_passed'),
  bgPassed40: $r('app.color.bg_morandi_passed_40'),

  indicatorCompleted: $r('app.color.indicator_morandi_completed'),
  indicatorCompleted50: $r('app.color.indicator_morandi_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_morandi_completed_70'),
  bgCompleted: $r('app.color.bg_morandi_completed'),
  bgCompleted40: $r('app.color.bg_morandi_completed_40'),
};

const INDICATORS_VIBRANT: IndicatorSet = {
  indicatorUndergo: $r('app.color.indicator_vibrant_undergo'),
  indicatorUndergo50: $r('app.color.indicator_vibrant_undergo_50'),
  indicatorUndergo70: $r('app.color.indicator_vibrant_undergo_70'),
  bgUndergo: $r('app.color.bg_vibrant_undergo'),
  bgUndergo40: $r('app.color.bg_vibrant_undergo_40'),

  indicatorNear: $r('app.color.indicator_vibrant_near'),
  indicatorNear50: $r('app.color.indicator_vibrant_near_50'),
  indicatorNear70: $r('app.color.indicator_vibrant_near_70'),
  bgNear: $r('app.color.bg_vibrant_near'),
  bgNear40: $r('app.color.bg_vibrant_near_40'),

  indicatorPassed: $r('app.color.indicator_vibrant_passed'),
  indicatorPassed50: $r('app.color.indicator_vibrant_passed_50'),
  indicatorPassed70: $r('app.color.indicator_vibrant_passed_70'),
  bgPassed: $r('app.color.bg_vibrant_passed'),
  bgPassed40: $r('app.color.bg_vibrant_passed_40'),

  indicatorCompleted: $r('app.color.indicator_vibrant_completed'),
  indicatorCompleted50: $r('app.color.indicator_vibrant_completed_50'),
  indicatorCompleted70: $r('app.color.indicator_vibrant_completed_70'),
  bgCompleted: $r('app.color.bg_vibrant_completed'),
  bgCompleted40: $r('app.color.bg_vibrant_completed_40'),
};

function createTheme(
  brand: ResourceColor,
  brand50: ResourceColor,
  accent: ResourceColor,
  bgPrimary: ResourceColor,
  indicators: IndicatorSet
): ITheme {
  return {
    brand: brand,
    brand50: brand50,
    accent: accent,
    bgPrimary: bgPrimary,

    indicatorUndergo: indicators.indicatorUndergo,
    indicatorUndergo50: indicators.indicatorUndergo50,
    indicatorUndergo70: indicators.indicatorUndergo70,
    bgUndergo: indicators.bgUndergo,
    bgUndergo40: indicators.bgUndergo40,

    indicatorNear: indicators.indicatorNear,
    indicatorNear50: indicators.indicatorNear50,
    indicatorNear70: indicators.indicatorNear70,
    bgNear: indicators.bgNear,
    bgNear40: indicators.bgNear40,

    indicatorPassed: indicators.indicatorPassed,
    indicatorPassed50: indicators.indicatorPassed50,
    indicatorPassed70: indicators.indicatorPassed70,
    bgPassed: indicators.bgPassed,
    bgPassed40: indicators.bgPassed40,

    indicatorCompleted: indicators.indicatorCompleted,
    indicatorCompleted50: indicators.indicatorCompleted50,
    indicatorCompleted70: indicators.indicatorCompleted70,
    bgCompleted: indicators.bgCompleted,
    bgCompleted40: indicators.bgCompleted40,
  };
}

export const ThemeMap: Record<string, ITheme> = {
  'classic': createTheme(
    $r('app.color.brand'),
    $r('app.color.brand_50'),
    $r('app.color.accent'),
    $r('app.color.background_primary'),
    INDICATORS_MORANDI
  ),
  'vibrant': createTheme(
    $r('app.color.brand_vibrant'),
    $r('app.color.brand_vibrant_50'),
    $r('app.color.accent_vibrant'),
    $r('app.color.background_primary'),
    INDICATORS_VIBRANT
  ),
  'nature': createTheme(
    $r('app.color.brand_nature'),
    $r('app.color.brand_nature_50'),
    $r('app.color.accent_nature'),
    $r('app.color.background_primary'),
    INDICATORS_MORANDI
  ),
  'sunset': createTheme(
    $r('app.color.brand_sunset'),
    $r('app.color.brand_sunset_50'),
    $r('app.color.accent_sunset'),
    $r('app.color.background_primary'),
    INDICATORS_MORANDI
  ),
  'lavender': createTheme(
    $r('app.color.brand_lavender'),
    $r('app.color.brand_lavender_50'),
    $r('app.color.accent_lavender'),
    $r('app.color.background_primary'),
    INDICATORS_MORANDI
  ),
  'harmony': createTheme(
    $r('sys.color.ohos_id_color_emphasize'),
    '#800A59F7',
    $r('sys.color.ohos_id_color_emphasize_contrary'),
    $r('app.color.background_primary'),
    INDICATORS_VIBRANT
  )
};