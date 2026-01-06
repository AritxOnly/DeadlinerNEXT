import {
  HdsNavDestination,
  HdsNavDestinationAttribute
} from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { TaskRepository } from '../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../common/repository/HabitRepository';
import { DDLStatus } from '../../../../model/DDLStatus';
import { DDLItemCardSwipeable } from '../../../components/TaskItemCard';
import { HabitRow, HabitWithDailyStatus } from '../../../components/HabitComponents';
import { FloatUpModifier } from '../../../../utils/animation/FloatUpModifier';
import { VibrationUtils } from '../../../../utils/VibrationUtils';
import { ConfettiController } from '../../../components/confetti/ConfettiController';
import { SearchUtils, TaskUIModel } from '../../../../utils/SearchUtils';

@Builder
export function SearchPageBuilder() {
  SearchPage()
}

@Component
export struct SearchPage {
  @Consume('appPathStack') appPathStack: NavPathStack;
  @StorageProp('statusBarHeight') statusBarHeight: number = 38;

  // 搜索状态
  @State searchText: string = '';
  @State isSearching: boolean = false; // 是否正在输入/处理中
  @State hasSearchTerm: boolean = false; // 是否有搜索词（用于区分初始态和搜索态）

  // 结果集
  @State taskResults: TaskUIModel[] = [];
  @State habitResults: HabitWithDailyStatus[] = [];

  // Logic 实例
  private logic = SearchUtils.getInstance();

  // 仓库实例用于更新状态 (Logic 只负责查，修删改还是在这里或 Logic 里都行，这里为了复用 UI 逻辑保留 Repo 调用)
  private taskRepo = TaskRepository.getInstance();
  private habitRepo = HabitRepository.getInstance();

  private scroller: Scroller = new Scroller();
  private confetti: ConfettiController = new ConfettiController();
  @State isFirstLoad: boolean = true;

  readonly SEARCH_INPUT_ID = 'search_input';

  // —— 生命周期 ——

  async aboutToAppear() {
    await this.logic.preloadData();

    getContext(this).eventHub.on('sync_done', () => {
      // 收到同步完成，重新预加载并刷新当前搜索
      this.logic.preloadData().then(() => {
        if (this.searchText) this.handleSearch(this.searchText);
      });
    });

    setTimeout(() => {
      // 请求焦点，这会自动弹出软键盘
      const res = focusControl.requestFocus(this.SEARCH_INPUT_ID);
      if (res) {
        console.debug('Focus success');
      } else {
        console.debug('Focus failed');
      }
    }, 500);

    setTimeout(() => {
      this.isFirstLoad = false;
    }, 750);
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  // —— 搜索逻辑调用 ——

  private async handleSearch(value: string) {
    this.searchText = value;
    const hasTerm = value.trim().length > 0;
    this.hasSearchTerm = hasTerm;

    if (!hasTerm) {
      this.taskResults = [];
      this.habitResults = [];
      return;
    }

    this.isSearching = true;
    const results = await this.logic.executeSearch(value);

    // 使用 animateTo 让列表变化更自然（可选）
    animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.taskResults = results.tasks;
      this.habitResults = results.habits;
      this.isSearching = false;
    })
  }

  // —— 交互操作 ——

  private async onTaskComplete(taskUI: TaskUIModel) {
    VibrationUtils.vibrateShort();
    try {
      const item = taskUI.originalItem;
      const newStatus = !item.isCompleted;
      item.isCompleted = newStatus;
      item.completeTime = newStatus ? new Date().toISOString() : "";

      if (newStatus) this.confetti.fire();

      await this.taskRepo.updateDDL(item);
      // 局部刷新结果
      this.handleSearch(this.searchText);
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Task complete failed', e);
    }
  }

  private async onHabitToggle(item: HabitWithDailyStatus) {
    VibrationUtils.vibrateShort();
    try {
      const today = new Date();
      await this.habitRepo.toggleRecord(item.habit.id, today);

      if (!item.isCompleted && (item.doneCount + 1 >= item.targetCount)) {
        this.confetti.fire();
      }

      this.handleSearch(this.searchText);
      getContext(this).eventHub.emit('sync_done');
    } catch (e) {
      console.error('Habit toggle failed', e);
    }
  }

  // —— UI Builders ——

  @Builder
  searchBuilder() {
    Row() {
      Search({
        value: this.searchText,
        placeholder: '搜索任务或习惯...',
      })
        .searchButton('搜索', {
          fontColor: $r('app.color.brand')
        })
        .id('search_input')
        .defaultFocus(true)
        .width('100%')
        .height(40)
        .placeholderColor($r('sys.color.ohos_id_color_text_secondary'))
        .onChange((value: string) => {
          this.handleSearch(value);
        })
    }
    .padding({ left: 64, right: 16 })
  }

  /**
   * 初始空状态（没有输入搜索词时）
   */
  @Builder
  buildEmptyPlaceholder() {
    Column({ space: 16 }) {
      // 图片占位 (可以换成 app.media.illustration_search 之类的)
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(80)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
        .opacity(0.5)

      Column({ space: 4 }) {
        Text('输入关键词进行搜索')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))

        Text('支持搜索标题、备注和鼓励语')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      }
    }
    .width('100%')
    .height('60%') // 占据屏幕主要部分
    .justifyContent(FlexAlign.Center)
  }

  /**
   * 搜索无结果（输入了词但没找到）
   */
  @Builder
  buildNoResultPlaceholder() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.nosign')) // 换个图标
        .fontSize(60)
        .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      Text('未找到相关内容')
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height(300)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight, scrollable: false }) {
        Column() {
          // 判断显示逻辑：
          // 1. 如果没有搜索词 -> 显示初始占位符
          // 2. 如果有搜索词 -> 显示列表（哪怕是空的，列表里会处理无结果的情况）

          if (!this.hasSearchTerm) {
            this.buildEmptyPlaceholder()
          } else {
            List({ scroller: this.scroller, space: 10 }) {
              ListItem() {
                Column().height(8)
              }

              // A. 任务组
              if (this.taskResults.length > 0) {
                ListItem() {
                  Text('任务')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }

                ForEach(this.taskResults, (item: TaskUIModel, index: number) => {
                  ListItem() {
                    DDLItemCardSwipeable({
                      title: item.title,
                      remainingTimeAlt: item.remainingTimeAlt,
                      note: item.note,
                      progress: item.progress,
                      isStarred: item.isStarred,
                      status: item.status,
                      selectionMode: false,
                      selected: false,
                      onComplete: (): Promise<void> => this.onTaskComplete(item),
                      onDelete: () => { promptAction.showToast({message: '请在主页进行删除操作'}) }
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index, 15, false))
                }, (item: TaskUIModel) => `task_${item.dbId}`)
              }

              // B. 习惯组
              if (this.habitResults.length > 0) {
                ListItem() {
                  Text('习惯')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 16, bottom: -4, left: 12 })
                }

                ForEach(this.habitResults, (item: HabitWithDailyStatus, index: number) => {
                  ListItem() {
                    HabitRow({
                      data: item,
                      status: item.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                      isSelected: false,
                      canToggle: true,
                      remainingText: "",
                      onToggle: (): Promise<void> => this.onHabitToggle(item),
                      onLongPress: () => {}
                    })
                  }
                  .attributeModifier(new FloatUpModifier(index + 5, 15, false))
                }, (item: HabitWithDailyStatus) => `habit_${item.habit.id}`)
              }

              // C. 搜索无结果 (有搜索词，但两边列表都空)
              if (this.taskResults.length === 0 && this.habitResults.length === 0) {
                ListItem() {
                  this.buildNoResultPlaceholder()
                }
              }

              // 底部留白
              ListItem().height(100)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .padding({ left: 12, right: 12 })
            // 添加出现动画
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .backgroundColor($r('app.color.background_primary'))
    .titleBar({
      content: {
        title: { mainTitle: '' },
        stackBuilder: this.searchBuilder.bind(this)
      }
    })
  }
}