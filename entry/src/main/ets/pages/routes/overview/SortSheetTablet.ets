import { OverviewViewModel } from './OverviewViewModel';
import {
  SegmentButton,
  SegmentButtonOptions,
  ItemRestriction,
  SegmentButtonTextItem
} from '@kit.ArkUI';
import { SortSheet } from './SortSheet'; // 引入子组件

@Component
export struct SortSheetTablet {
  @Link viewModel: OverviewViewModel;
  onClose: () => void = () => {};

  // 内部状态：控制显示哪个列表
  @State selectedIndexes: number[] = [0];

  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '总览卡片' },
      { text: '趋势图表' }
    ] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.NONE,
    selectedBackgroundColor: $r('sys.color.segment_button_v2_tab_selected_item_background'),
    buttonPadding: 8
  })

  build() {
    Column() {
      Column() {
        SegmentButton({
          options: this.tabOptions,
          selectedIndexes: $selectedIndexes
        })
          .width('80%')
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