import { TopSafeContainer } from "../../components/TopSafeContainer"

@Component
export struct HabitListSection {
  @Prop topAvoidHeight: number = 0;

  scroller: Scroller = new Scroller();

  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight }) {
        List({ scroller: this.scroller }) {
          ListItem() {
            Text('习惯列表占位（后面接 Habit 数据）')
              .fontSize(16)
              .padding(24)
          }
        }
        .width('100%')
        .height('100%')
        .nestedScroll({
          scrollForward: NestedScrollMode.PARENT_FIRST, // 手指上滑：先让外层(TopSafe)把Blank滚上去，剩下的List自己滚
          scrollBackward: NestedScrollMode.SELF_FIRST   // 手指下滑：List先滚回顶部，然后外层(TopSafe)再把Blank拉下来
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}