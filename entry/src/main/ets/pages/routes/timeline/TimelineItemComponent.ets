import { TimelineItem, TimelineItemType } from './TimelineModels';
import { DDLItemCardSwipeable } from '../../components/TaskItemCard';
import { HabitRow } from '../../components/HabitComponents';
import { DDLStatus } from '../../../model/DDLStatus';

@Component
export struct TimelineItemComponent {
  @Prop item: TimelineItem;
  @Prop isLast: boolean;

  // 辅助样式
  readonly DOT_COLOR: ResourceColor = $r('sys.color.ohos_id_color_primary');
  readonly CARD_RADIUS: number = 24;

  // 回调函数：把操作权交还给父组件
  onTaskComplete: (dbId: number) => void = () => {};
  onTaskDelete: (dbId: number) => void = () => {};
  onHabitToggle: (habitId: number, dateTs: number) => void = () => {};

  private isPast(timestamp: number): boolean {
    return timestamp < new Date().getTime();
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  build() {
    Row() {
      // 1. 左侧时间轴
      Stack({ alignContent: Alignment.Top }) {
        if (!this.isLast) {
          Line()
            .width(2)
            .height('100%')
            .backgroundColor($r('sys.color.comp_divider'))
            .margin({ top: 14 })
        }

        Circle({ width: 10, height: 10 })
          .fill($r('app.color.background_primary'))
          .stroke(this.isPast(this.item.sortTime) ? $r('sys.color.comp_divider') : this.DOT_COLOR)
          .strokeWidth(2)
          .margin({ top: 6 })
      }
      .width(40)
      .padding({ left: 18 })
      .height('100%')

      // 2. 右侧内容
      Column() {
        Text(this.formatTime(this.item.sortTime))
          .fontSize(13)
          .fontColor($r('app.color.font_secondary'))
          .fontWeight(FontWeight.Medium)
          .opacity(0.8)
          .width('100%')
          .margin({ bottom: 6, left: 8 })

        Stack() {
          Column() {
            // [逻辑分支] 渲染 Task
            if (this.item.type === TimelineItemType.TASK && this.item.taskData) {
              DDLItemCardSwipeable({
                title: this.item.taskData.title,
                remainingTimeAlt: this.item.taskData.remainingTimeAlt,
                note: this.item.taskData.note,
                progress: this.item.taskData.progress,
                isStarred: this.item.taskData.isStarred,
                status: this.item.taskData.status,
                selectionMode: false,
                selected: false,
                // [交互] 调用传入的回调
                onComplete: () => {
                  if (this.item.taskData) this.onTaskComplete(this.item.taskData.dbId);
                },
                onDelete: () => {
                  if (this.item.taskData) this.onTaskDelete(this.item.taskData.dbId);
                }
              })
            }
            // [逻辑分支] 渲染 Habit
            else if (this.item.type === TimelineItemType.HABIT && this.item.habitData) {
              HabitRow({
                data: this.item.habitData,
                status: this.item.habitData.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                isSelected: false,
                canToggle: true,
                remainingText: "",
                onToggle: () => {
                  if (this.item.habitData) {
                    this.onHabitToggle(this.item.habitData.habit.id, this.item.sortTime);
                  }
                },
                onLongPress: () => {}
              })
            }
          }
        }
        .width('100%')
        .borderRadius(this.CARD_RADIUS)
        .clip(true)
        .grayscale(this.isPast(this.item.sortTime) ? 0.95 : 0)
        .opacity(this.isPast(this.item.sortTime) ? 0.7 : 1)
      }
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .height(this.item.type === TimelineItemType.HABIT ? 108 : 112)
  }
}