import { OverviewViewModel } from './OverviewViewModel';
import {
  ColorMetrics,
  LengthMetrics,
  SegmentButtonV2Items,
  TabSegmentButtonV2,
  uiMaterial
} from '@kit.ArkUI';
import { SortSheet } from './SortSheet'; // 引入子组件
import { buildImmersiveMaterial, canUseSystemMaterial } from '../../../common/style/SystemMaterialCompat';

@Component
export struct SortSheetTablet {
  @Link viewModel: OverviewViewModel;
  onClose: () => void = () => {};

  // 内部状态：控制显示哪个列表
  @State selectedIndexes: number[] = [0];

  readonly tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '总览卡片' },
    { text: '趋势图表' }
  ]);

  private onSelectedIndexChange(index: number): void {
    this.selectedIndexes = [index];
  }

  @Builder
  private buildTabSegment() {
    if (canUseSystemMaterial()) {
      TabSegmentButtonV2({
        items: this.tabItems,
        selectedIndex: this.selectedIndexes[0],
        $selectedIndex: (index: number): void => {
          this.onSelectedIndexChange(index);
        },
        itemSelectedBackgroundColor: ColorMetrics.rgba(255, 255, 255, 0.16),
        itemMinHeight: LengthMetrics.vp(32),
        buttonBackgroundColor: ColorMetrics.rgba(0, 0, 0, 0),
        buttonMinHeight: LengthMetrics.vp(40),
        buttonPadding: LengthMetrics.vp(4),
        backgroundSystemMaterial: buildImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.THIN,
          interactive: true,
          lightEffect: true
        }),
        enableStateAnimation: true
      })
    } else {
      TabSegmentButtonV2({
        items: this.tabItems,
        selectedIndex: this.selectedIndexes[0],
        $selectedIndex: (index: number): void => {
          this.onSelectedIndexChange(index);
        },
        itemSelectedBackgroundColor: ColorMetrics.resourceColor(
          $r('sys.color.segment_button_v2_tab_selected_item_background')
        ),
        buttonPadding: LengthMetrics.vp(8),
        enableStateAnimation: true
      })
    }
  }

  build() {
    Column() {
      Column() {
        Column() {
          this.buildTabSegment()
        }
        .width('80%')
        .height(48)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ bottom: 12 })

      SortSheet({
        viewModel: $viewModel,
        selectedTabIndex: this.selectedIndexes[0]
      })
    }
    .height('100%')
  }
}
