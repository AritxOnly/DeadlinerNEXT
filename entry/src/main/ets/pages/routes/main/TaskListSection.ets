import { DDLStatus } from "../../../model/DDLStatus";
import { DDLItemCardSwipeable } from "../../components/TaskItemCard";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { DDLItem, DeadlineType } from "../../../model/DDLModels";
import { TaskRepository } from "../../../data/repository/TaskRepository";
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { TopSafeContainer } from "../../components/TopSafeContainer";

interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
  dbId: number;
}

@Component
export struct TaskListSection {
  scroller: Scroller = new Scroller()

  @State taskList: Array<TaskUIModel> = [];
  @State isRefreshing: boolean = false; // 控制下拉刷新状态

  @State isLoading: boolean = true;
  @Prop topAvoidHeight: number = 0;

  private repo = TaskRepository.getInstance();

  async aboutToAppear() {
    await this.loadData();

    // 监听同步完成事件，自动刷新
    getContext(this).eventHub.on('sync_done', () => {
      console.info('[TaskList] Received sync_done event, reloading...');
      this.loadData();
    });

    this.repo.syncNow().catch((e: Error) => console.error(e.message));
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  // 加载数据：过滤 + 排序 + 映射
  async loadData() {
    try {
      this.isLoading = true;

      const dbItems = await this.repo.getDDLsByType(DeadlineType.TASK);

      const now = new Date().getTime();

      // 2. 预处理：过滤 & 排序
      const processedItems = dbItems
        .filter((item) => {
          // 过滤条件：未归档 (isArchived=false) 且 未删除 (deleted=false)
          // 注意：getAllDDLs SQL层可能已经过滤了 deleted，但这里双重保障
          return !item.isArchived && !item.deleted && item.type !== DeadlineType.HABIT
        })
        .sort((a, b) => {
          if (a.isCompleted && !b.isCompleted) return 1;  // a完成，b未完成 -> a放后面
          if (!a.isCompleted && b.isCompleted) return -1; // a未完成，b完成 -> a放前面

          // 逻辑B：状态相同时，按截止时间排序（越早越靠前）
          const timeA = new Date(a.endTime).getTime();
          const timeB = new Date(b.endTime).getTime();
          return timeA - timeB;
        });

      // 3. 映射为 UI 模型
      this.taskList = processedItems.map((item) => {
        return this.mapToUI(item, now);
      });

      console.info(`[TaskList] Loaded ${this.taskList.length} items.`);
    } catch (e) {
      console.error(`[TaskList] Load data failed: ${e}`);
    } finally {
      // 无论成功失败，都要关闭刷新动画
      this.isRefreshing = false;
      this.isLoading = false;
    }
  }

  // 核心逻辑：数据映射 (DB Model -> UI Model)
  private mapToUI(item: DDLItem, now: number): TaskUIModel {
    // 简单的日期解析容错
    const parseDate = (str: string): number => {
      const d = new Date(str);
      return isNaN(d.getTime()) ? 0 : d.getTime();
    };

    const start = parseDate(item.startTime);
    const end = parseDate(item.endTime);

    // 1. 计算状态
    let status = DDLStatus.UNDERGO;
    if (item.isCompleted) {
      status = DDLStatus.COMPLETED;
    } else if (now > end) {
      status = DDLStatus.PASSED;
    } else if ((end - now) < 24 * 60 * 60 * 1000) {
      status = DDLStatus.NEAR;
    } else {
      status = DDLStatus.UNDERGO;
    }

    // 2. 计算进度
    let progress = 0.0;
    if (item.isCompleted) {
      progress = 1.0;
    } else {
      const totalDuration = end - start;
      const elapsed = now - start;
      if (totalDuration > 0) {
        progress = Math.max(0, Math.min(1, elapsed / totalDuration));
      } else {
        progress = 0;
      }
    }

    // 3. 计算剩余时间文本
    let timeText = "";
    if (item.isCompleted) {
      timeText = "已完成";
    } else {
      const diffMs = end - now;
      if (diffMs < 0) {
        timeText = "已逾期 " + Math.abs(Math.floor(diffMs / (1000 * 60 * 60))) + " 小时";
      } else {
        const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        if (days > 0) {
          timeText = `${days}天 ${hours}小时`;
        } else {
          timeText = `${hours}小时`;
        }
      }
    }

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: 1.0 - progress,
      isStarred: item.isStared,
      status: status,
      dbId: item.id
    };
  }

  private async handleComplete(dbId: number) {
    VibrationUtils.vibrateShort();

    try {
      // 1. 获取原始数据 (为了简单，这里重新查库，或者你可以维护一个 Map<id, DDLItem>)
      // 由于我们 loadData 时只拿了部分字段转 UI Model，最好重新 fetch 一下确保拿到最新全量字段
      const allItems = await this.repo.getAllDDLs();
      const targetItem = allItems.find(item => item.id === dbId);

      if (!targetItem) {
        console.warn('Item not found for complete');
        return;
      }

      // 2. 状态反转
      const newStatus = !targetItem.isCompleted;
      targetItem.isCompleted = newStatus;

      // 3. 更新完成时间
      if (newStatus) {
        targetItem.completeTime = new Date().toISOString(); // 或者用你之前的 formatLocalDateTime
      } else {
        targetItem.completeTime = "";
      }

      // 4. 写库 + 触发同步
      await this.repo.updateDDL(targetItem);

      // 5. 刷新 UI
      // 优化体验：这里可以直接修改 this.taskList 本地状态做乐观更新，但重新 loadData 最稳妥
      await this.loadData();

      promptAction.showToast({
        message: newStatus ? '任务已完成' : '任务已重置'
      });

    } catch (e) {
      console.error(`Complete failed: ${e}`);
      promptAction.showToast({ message: '操作失败' });
    }
  }

  private handleDelete(dbId: number, title: string) {
    VibrationUtils.vibrateMedium();

    // 弹出确认框
    AlertDialog.show({
      title: '删除确认',
      message: `确定要删除任务 "${title}" 吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        action: () => {
          // 可以在这里重置 Swipe 状态（如果需要）
          // 但你的 DDLItemCardSwipeable 组件内部逻辑如果正确，不操作就会自动回弹
          // 由于你是滑动触发，如果这里不删，Swipe 组件可能停留在已滑开状态，
          // 你的组件逻辑里 resetSwipe 是在 onActionEnd 里调用的吗？
          // 如果是 SwipeToDismissBox，通常取消后会自动回弹。

          // 如果你的组件没有自动回弹，可能需要强制刷新一下列表复位
          this.loadData();
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            await this.repo.deleteDDL(dbId);
            await this.loadData();
            promptAction.showToast({ message: '已删除' });
          } catch (e) {
            console.error(`Delete failed: ${e}`);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    })
  }

  @Builder RefreshHeader() {
    Stack({ alignContent: Alignment.Bottom }) {
      LoadingProgress()
        .width(24)
        .height(24)
        .color($r('app.color.brand'))
    }
    .width("100%")
    .height(64) // 保持标准的触发高度
    // 【核心技巧】
    // 使用 translate 仅仅改变视觉位置，不改变布局占位。
    // 这样 Refresh 组件认为 Header 还在顶部，正常触发刷新；
    // 但用户看到的转圈圈已经被移到了标题栏下方。
    .translate({ y: this.topAvoidHeight })
  }

  build() {
    Column() {
      if (this.isLoading && this.taskList.length === 0) {
        LoadingProgress()
          .width(50)
          .height(50)
          .margin({ top: 100 })
      } else {
        // 使用新封装的组件
        TopSafeContainer({ topAvoidHeight: this.topAvoidHeight }) {
          Column() {
            // Refresh 包裹 List
            Refresh({ refreshing: $$this.isRefreshing }) {
              List({
                space: 8,
                scroller: this.scroller,
              }) {
                ForEach(this.taskList, (item: TaskUIModel) => {
                  ListItem() {
                    DDLItemCardSwipeable({
                      title: item.title,
                      remainingTimeAlt: item.remainingTimeAlt,
                      note: item.note,
                      progress: item.progress,
                      isStarred: item.isStarred,
                      status: item.status,
                      onComplete: async () => { this.handleComplete(item.dbId) },
                      onDelete: async () => { this.handleDelete(item.dbId, item.title) }
                    })
                  }
                }, (item: TaskUIModel) => `${item.dbId}_${item.status}_${item.progress}`)

                ListItem() {
                  Divider().color(Color.Transparent).height(100)
                }
              }
              .width("100%")
              .height("100%") // 撑满 TopSafeContainer 的剩余空间
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .nestedScroll({
                scrollForward: NestedScrollMode.PARENT_FIRST,
                scrollBackward: NestedScrollMode.PARENT_FIRST
              })
              .padding({
                start: LengthMetrics.vp(12), end: LengthMetrics.vp(12)
              })
            }
            .onRefreshing(async () => {
              this.isRefreshing = true
              try {
                await this.repo.syncNow();
              } catch (e) {
                console.error('Manual sync failed');
              }
              await this.loadData();
              this.isRefreshing = false;
            })
          }
        }
      }
    }
    .width("100%")
    .height("100%")
    // 外部也需要扩展，确保 TopSafeContainer 能拿到全屏空间
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}