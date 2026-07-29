import { DividerMode, hdsMaterial, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { ITheme } from '../../common/theme/ThemeModel';
import { LocalValues } from '../../common/local/LocalValues';
import { getHdsMaterialLevel } from '../../common/style/MaterialLevel';
import { HarmonyOSCapabilities } from '../../common/platform/HarmonyOSCapabilities';

@Component
export struct AdaptedHdsTabs {
  // 核心数据的双向绑定
  @Link currentIndex: number;

  // 布局控制参数
  @Prop isWideScreen: boolean;
  @Prop tabletUi: boolean;
  @Prop theme: ITheme;
  @StorageProp('isCompactHeight') isCompactHeight: boolean = false;

  // 控制器
  controller: HdsTabsController = new HdsTabsController();

  // 接收外部传入的 TabContent 内容
  @BuilderParam content: () => void;

  // 点击事件回调（把业务逻辑抛给父组件）
  onTabClick?: (index: number) => void;

  onMiniBarClick?: () => void;

  build() {
    if (HarmonyOSCapabilities.supportsImmersiveMaterial() &&
      LocalValues.getInstance().isImmersiveMaterialEnabled()) {

      HdsTabs({
        barPosition: BarPosition.End,
        index: this.currentIndex,
        controller: this.controller
      }) {
        this.content()
      }
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .divider({ mode: DividerMode.NONE })
        .barFloatingStyle({
          barSideMargin: this.isCompactHeight ? 12 : 24,
          barBottomMargin: this.isCompactHeight ? 8 : (this.isWideScreen ? 24 : 12),
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: getHdsMaterialLevel()
          },
          gradientMask: {
            maskColor: $r('app.color.background_primary_50'),
            maskHeight: this.isCompactHeight ? 30 : 42
          },
          lightColor: this.theme.useWhiteGlow ? Color.White : this.theme.brand50,
          adaptToHandedness: this.isWideScreen,
          thermoCtrl: true
        })
    } else {
      if (this.isWideScreen && this.tabletUi) {
        HdsTabs({
          barPosition: BarPosition.Start,
          index: this.currentIndex,
          controller: this.controller
        }) {
          this.content()
        }
        .vertical(true)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .divider({ mode: DividerMode.NONE })
        .barBackgroundEffect({
          radius: 0,
          color: this.theme.bgPrimary
        })
      } else {
        HdsTabs({
          barPosition: BarPosition.End,
          index: this.currentIndex,
          controller: this.controller
        }) {
          this.content()
        }
        .vertical(false)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // .background(this.theme.bgPrimary)
        .animationDuration(300)
        .scrollable(false)
        .height('100%')
        .width('100%')
        .onChange((index: number) => {
          this.currentIndex = index;
        })
        .onTabBarClick((index: number) => {
          if (this.onTabClick) {
            this.onTabClick(index);
          }
        })
        .clip(false)
        .divider({ mode: DividerMode.NONE })
      }
    }
  }
}
