@Component
export struct HabitListSection {
  build() {
    Column() {
      Text('习惯列表占位（后面接 Habit 数据）')
        .fontSize(16)
        .padding(24)
    }
    .width('100%')
    .height('100%')
  }
}