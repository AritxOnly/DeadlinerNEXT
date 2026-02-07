import { LengthMetrics } from '@kit.ArkUI';
import { FloatUpModifier } from '../../../utils/animation/FloatUpModifier';
import { PressEffectModifier } from '../../../utils/animation/PressModifier';
import { DDLItemCardSwipeable } from '../../components/TaskItemCard';
import { HabitRow } from '../../components/HabitComponents';
import { TimelineGroup, TimelineItem, TimelineItemType } from './TimelineModels';
import { TimelineViewModel } from './TimelineViewModel';
import { DDLStatus } from '../../../model/DDLStatus'

@Component
export struct TimelineSection {
  @State viewModel: TimelineViewModel = new TimelineViewModel();
  @State isFirstLoad: boolean = true;
  @State isRefreshing: boolean = false;

  @Prop topInset: number = 0;

  scroller: Scroller = new Scroller();

  // 定义样式常量
  readonly LINE_COLOR: ResourceColor = $r('sys.color.comp_divider');
  readonly DOT_COLOR: ResourceColor = $r('sys.color.ohos_id_color_primary');
  readonly CARD_RADIUS: number = 24;


  aboutToAppear() {
    this.viewModel.refreshData();
    getContext(this).eventHub.on('sync_done', this.onSyncEvent);
    setTimeout(() => { this.isFirstLoad = false; }, 500);
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('sync_done', this.onSyncEvent);
  }

  private onSyncEvent = () => {
    console.info('[TimelineSection] Received sync_done, refreshing...');
    this.viewModel.refreshData();
  }

  private isPast(timestamp: number): boolean {
    return timestamp < new Date().getTime();
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  @Builder
  GroupHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
    }
    .width('100%')
    .padding({ left: 16, top: 16, bottom: 8 })
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .background($r('app.color.background_primary'))
  }

  @Builder
  EmptyView() {
    Column() {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(80)
        .fontColor([$r('app.color.font_secondary')])
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .opacity(0.5)
      Text("暂无日程安排")
        .margin({ top: 16 })
        .fontSize(16)
        .fontColor($r('app.color.font_secondary'))
    }
    .width('100%')
    .height('60%')
    .justifyContent(FlexAlign.Center)
    .opacity(0.8)
  }

  @Builder
  TimelineItemRow(item: TimelineItem, isLast: boolean) {
    Row() {
      Stack({ alignContent: Alignment.Top }) {
        if (!isLast) {
          Line()
            .width(2)
            .height('100%')
            .backgroundColor($r('sys.color.comp_divider'))
            .margin({ top: 14 })
        }

        Circle({ width: 10, height: 10 })
          .fill($r('app.color.background_primary'))
          .stroke(this.isPast(item.sortTime) ? $r('sys.color.comp_divider') : this.DOT_COLOR)
          .strokeWidth(2)
          .margin({ top: 6 })
      }
      .width(40)
      .padding({ left: 18 }) // 整体左边距，让轴线不贴边
      .height('100%')

      Column() {
        // 时间文本：更精致的小标题风格
        Text(this.formatTime(item.sortTime))
          .fontSize(13) // 字号微调，显精致
          .fontColor($r('app.color.font_secondary'))
          .fontWeight(FontWeight.Medium)
          .opacity(0.8) // 稍微降低透明度，不抢视觉重点
          .width('100%')
          .margin({ bottom: 6, left: 8 }) // bottom:8 给卡片留出呼吸空间

        // 卡片区域
        Stack() {
          Column() {
            if (item.type === TimelineItemType.TASK && item.taskData) {
              DDLItemCardSwipeable({
                title: item.taskData.title,
                remainingTimeAlt: item.taskData.remainingTimeAlt,
                note: item.taskData.note,
                progress: item.taskData.progress,
                isStarred: item.taskData.isStarred,
                status: item.taskData.status,
                selectionMode: false,
                selected: false,
                onComplete: () => { if (item.taskData) this.viewModel.completeTask(item.taskData.dbId); },
                onDelete: () => { if (item.taskData) this.viewModel.deleteTask(item.taskData.dbId); }
              })
            }
            else if (item.type === TimelineItemType.HABIT && item.habitData) {
              HabitRow({
                data: item.habitData,
                status: item.habitData.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                isSelected: false,
                canToggle: true,
                remainingText: "",
                onToggle: () => { if (item.habitData) this.viewModel.toggleHabit(item.habitData.habit.id); },
                onLongPress: () => {}
              })
            }
          }

          // 过期遮罩（样式保持不变）
          if (this.isPast(item.sortTime)) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('#0A000000')
              .hitTestBehavior(HitTestMode.None)
          }
        }
        .width('100%')
        .borderRadius(this.CARD_RADIUS)
        .clip(true)
        .grayscale(this.isPast(item.sortTime) ? 0.95 : 0)
        .opacity(this.isPast(item.sortTime) ? 0.7 : 1)
      }
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .height(item.type === TimelineItemType.HABIT ? 108 : 112)
  }

  build() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.viewModel.groups.length === 0 && !this.viewModel.isLoading) {
          Column() {
            Column().height(this.topInset)
            this.EmptyView()
          }
        } else {
          List({ scroller: this.scroller, space: 0 }) {
            ForEach(this.viewModel.groups, (group: TimelineGroup) => {

              // 吸顶 Header
              ListItemGroup({ header: this.GroupHeader(group.title) }) {
                ForEach(group.items, (item: TimelineItem, index: number) => {
                  ListItem() {
                    this.TimelineItemRow(item, index === group.items.length - 1)
                  }
                  .attributeModifier(new FloatUpModifier(index, 10, this.isFirstLoad))
                  .padding({ right: 16 }) // 列表右边距
                }, (item: TimelineItem) => item.id)
              }
            }, (group: TimelineGroup) => group.groupId)

            // 底部留白
            ListItem() {
              Column().height(120)
            }
          }
          .width('100%')
          .height('100%')
          .divider(null)
          .sticky(StickyStyle.Header)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .padding({ top: this.topInset })
        }
      }
      .onRefreshing(async () => {
        this.isRefreshing = true;
        await this.viewModel.refreshData();
        this.isRefreshing = false;
      })
    }
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
    .width('100%')
    .backgroundColor($r('app.color.background_primary'))
  }
}