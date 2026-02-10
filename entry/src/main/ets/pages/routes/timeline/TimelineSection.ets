import { LengthMetrics } from '@kit.ArkUI';
import { FloatUpModifier } from '../../../utils/animation/FloatUpModifier';
import { PressEffectModifier } from '../../../utils/animation/PressModifier';
import { DDLItemCardSwipeable } from '../../components/TaskItemCard';
import { HabitRow } from '../../components/HabitComponents';
import { TimelineGroup, TimelineItem, TimelineItemType } from './TimelineModels';
import { TimelineViewModel } from './TimelineViewModel';
import { DDLStatus } from '../../../model/DDLStatus'
import { ConfettiController } from '../../components/confetti/ConfettiController';
import { TimelineItemComponent } from './TimelineItemComponent';

@Component
export struct TimelineSection {
  @State viewModel: TimelineViewModel = new TimelineViewModel();

  @State groups: TimelineGroup[] = [];

  @State isFirstLoad: boolean = true;
  @State isRefreshing: boolean = false;

  @State confetti: ConfettiController = new ConfettiController();

  @Prop topInset: number = 0;

  scroller: Scroller = new Scroller();

  @State updateSeed: number = 0;

  // 定义样式常量
  readonly LINE_COLOR: ResourceColor = $r('sys.color.comp_divider');
  readonly DOT_COLOR: ResourceColor = $r('sys.color.ohos_id_color_primary');
  readonly CARD_RADIUS: number = 24;


  aboutToAppear() {
    this.reloadUI().then(() => {
      this.scrollToToday();
    });
    getContext(this).eventHub.on('sync_done', this.onSyncEvent);
    setTimeout(() => { this.isFirstLoad = false; }, 500);
  }

  private scrollToToday() {
    setTimeout(() => {
      if (this.viewModel.todayIndex > 0) {
        this.scroller.scrollToIndex(this.viewModel.todayIndex, true); // true = smooth animation
      }
    }, 100);
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('sync_done', this.onSyncEvent);
  }

  private onSyncEvent = () => {
    this.reloadUI();
  }

  private async reloadUI() {
    await this.viewModel.refreshData();
    this.groups = [...this.viewModel.groups];
  }

  private async handleTaskComplete(dbId: number) {
    await this.viewModel.completeTask(dbId, () => {
      this.confetti?.fire();
    });

    this.groups = [...this.viewModel.groups];
    this.updateSeed++;
  }

  private async handleHabitToggle(habitId: number, dateTs: number) {
    console.info(`[Timeline] Handle Habit Toggle: ${habitId}`);
    await this.viewModel.toggleHabit(habitId, dateTs, (): void => this.confetti?.fire());

    this.groups = [...this.viewModel.groups];
    this.updateSeed++;
  }

  // 处理删除
  private async handleTaskDelete(dbId: number) {
    await this.viewModel.deleteTask(dbId);
    this.groups = [...this.viewModel.groups];
    this.updateSeed++;
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
    // .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
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

  build() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.groups.length === 0 && !this.viewModel.isLoading) {
          Column() {
            Column().height(this.topInset)
            this.EmptyView()
          }
        } else {
          List({ scroller: this.scroller, space: 0 }) {
            ForEach(this.groups, (group: TimelineGroup) => {

              // 吸顶 Header
              ListItemGroup({ header: this.GroupHeader(group.title) }) {
                ForEach(group.items, (item: TimelineItem, index: number) => {
                  ListItem() {
                    // this.TimelineItemRow(item, index === group.items.length - 1)
                    TimelineItemComponent({
                      item: item, // 传递数据，自动响应变化
                      isLast: index === group.items.length - 1,

                      // 传递回调函数
                      onTaskComplete: (id): Promise<void> => this.handleTaskComplete(id),
                      onTaskDelete: (id): Promise<void> => this.handleTaskDelete(id),
                      onHabitToggle: (id, date): Promise<void> => this.handleHabitToggle(id, date)
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index, 10, this.isFirstLoad))
                  .padding({ right: 16 }) // 列表右边距
                }, (item: TimelineItem) => {
                  let key = item.id;
                  if (item.type === TimelineItemType.TASK && item.taskData) {
                    key = `${item.id}_${item.taskData.status}_${item.taskData.progress}`;
                  } else if (item.type === TimelineItemType.HABIT && item.habitData) {
                    key = `${item.id}_${item.habitData.isCompleted}_${item.habitData.doneCount}`;
                  }
                  console.info(`[Timeline] KeyGen: ${key}`); // 调试时打开，平时关掉以免刷屏
                  return key;
                })
              }
            }, (group: TimelineGroup) => `${group.groupId}_${this.updateSeed}`)

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
        await this.reloadUI();
        this.isRefreshing = false;
      })
    }
    .justifyContent(FlexAlign.Start)
    .constraintSize({ minHeight: '100%' })
    .width('100%')
    .backgroundColor($r('app.color.background_primary'))
  }
}