import { Theme } from '@kit.ArkUI'
import { ChipGroup, ChipSize } from '@kit.ArkUI'
import { FloatingAddButton } from '../../components/FloatingAddButton'
import { HabitListSection } from './HabitListSection'
import { TaskListSection } from './TaskListSection'

enum MainTabIndex {
  TASKS = 0,
  HABITS = 1,
}

@Component
export struct MainHomePage {
  @State currentIndex: number = MainTabIndex.TASKS
  @State selectedIndexes: Array<number> = [MainTabIndex.TASKS]

  // 这些 State 由主题驱动
  @State chipSelectedBg: ResourceColor = '#FFFFFF'
  @State chipSelectedFont: ResourceColor = '#000000'
  @State chipUnselectedFont: ResourceColor = '#00000099'
  @State pageBackground: ResourceColor = '#FFFFFFFF'
  @State fabBg: ResourceColor = '#6E8B74'
  @State fabIconColor: ResourceColor = '#FFFFFFFF'

  onWillApplyTheme(theme: Theme) {
    this.chipSelectedBg = theme.colors.interactiveActive
    this.chipSelectedFont = theme.colors.fontPrimary
    this.chipUnselectedFont = theme.colors.fontSecondary
    this.pageBackground = theme.colors.backgroundPrimary
    this.fabBg = theme.colors.interactiveActive
    this.fabIconColor = theme.colors.iconEmphasize
  }

  build() {
    Column() {
      // 顶部 ChipGroup
      ChipGroup({
        items: [
          { label: { text: '任务' } },
          { label: { text: '习惯' } },
        ],
        itemStyle: {
          size: ChipSize.NORMAL,
          selectedBackgroundColor: this.chipSelectedBg,
          selectedFontColor: this.chipSelectedFont,
          fontColor: this.chipUnselectedFont,
        },
        selectedIndexes: this.selectedIndexes,
        multiple: false,
        onChange: (indexes: Array<number>) => {
          if (indexes.length > 0) {
            this.selectedIndexes = [...indexes]
            this.currentIndex = indexes[0]
          }
        },
      })

      RelativeContainer() {
        // 列表内容：铺满整个容器
        if (this.currentIndex === MainTabIndex.TASKS) {
          TaskListSection()
            .id('content')
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
            })
        } else {
          HabitListSection()
            .id('content')
            .alignRules({
              top: { anchor: '__container__', align: VerticalAlign.Top },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
            })
        }

        // FAB：相对容器底部 + 水平居中
        FloatingAddButton({
          onClickAdd: () => {
            console.debug('Add Button Clicked')
          }
        })
          .id('fab')
          .alignRules({
            bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
            middle: { anchor: '__container__', align: HorizontalAlign.Center },
          })
          .margin({ bottom: 24 }) // 往上抬一点
      }
      .layoutWeight(1)  // 占满 ChipGroup 下方所有剩余高度
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground)
  }
}
