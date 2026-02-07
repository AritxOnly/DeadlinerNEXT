import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@hms.hds.hdsBaseComponent";
import { LengthMetrics } from "@kit.ArkUI";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { TimelineSection } from "./TimelineSection";
import { DividerShowType, HideMode } from "@kit.UIDesignKit";

@Component
export struct TimelinePage {
  readonly SEGMENT_HEIGHT: number = 18;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  build() {
    HdsNavigation() {
      TimelineSection({
        topInset: this.SEGMENT_HEIGHT + this.statusBarHeight
      })
    }
      .titleBar({
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.COMMON_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(10),
          },
          originalStyle: {
            backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_background_transparent') },
          },
          scrollEffectStyle: {
            backgroundStyle: { backgroundColor: $r('sys.color.ohos_id_color_navigation_background_blur') },
          },
        },
        content: {
          title: { mainTitle: '时间线' },
          divider: { showType: DividerShowType.OFF }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .mode(NavigationMode.Stack)
      .navBarWidth('100%')
  }
}