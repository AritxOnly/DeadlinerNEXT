import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode, ScrollEffectType } from "@hms.hds.hdsBaseComponent";
import { LengthMetrics } from "@kit.ArkUI";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { TimelineSection } from "./TimelineSection";
import { DividerShowType, HideMode } from "@kit.UIDesignKit";
import { getImmersiveTitleBarStyle } from "../../../common/style/NavStyles";
import { ConfettiView } from "../../components/confetti/ConfettiView";
import { ConfettiController } from "../../components/confetti/ConfettiController";

@Component
export struct TimelinePage {
  readonly SEGMENT_HEIGHT: number = 18;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  @State confettiController: ConfettiController = new ConfettiController();

  build() {
    HdsNavigation() {
      Stack() {
        TimelineSection({
          topInset: this.SEGMENT_HEIGHT + this.statusBarHeight,
          confetti: this.confettiController
        })

        ConfettiView({
          controller: this.confettiController,
          colors: ['#fce18a', '#ff726d', '#f4306d', '#b48def']
        })
          .hitTestBehavior(HitTestMode.None)
          .width('100%')
          .height('100%')
      }
      .width('100%')
      .height('100%')
    }
      .titleBar({
        style: getImmersiveTitleBarStyle(true),
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
      // .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
  }
}