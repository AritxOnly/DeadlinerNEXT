import { TopSafeContainer } from "../../components/TopSafeContainer"

@Component
export struct HabitListSection {
  @Prop topAvoidHeight: number = 0;

  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight }) {
        Column() {
          Text('习惯列表占位（后面接 Habit 数据）')
            .fontSize(16)
            .padding(24)
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}