import { DDLStatus } from "../../../model/DDLStatus";
import { DDLItemCardSwipeable } from "../../components/TaskItemCard";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { DDLItem, DeadlineType } from "../../../model/DDLModels";
import { TaskRepository } from "../../../common/repository/TaskRepository";
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { TopSafeContainer } from "../../components/TopSafeContainer";
import { TaskListController } from "./TaskListController"
import { ConfettiController } from "../../components/confetti/ConfettiController";
import { TimeInputButton } from "../../components/TimeInputButton";
import { SettingsConstants as C } from "../../../common/local/SettingsConstants"

const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

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
  scroller: Scroller = new Scroller();

  @State taskList: Array<TaskUIModel> = [];
  @State isRefreshing: boolean = false; // 控制下拉刷新状态

  @State isLoading: boolean = true;
  @Prop topAvoidHeight: number = 0;

  // 多选模式
  @Link isSelectionMode: boolean;
  @Require controller: TaskListController = new TaskListController();
  @State selectedIds: number[] = [];

  @Prop confetti: ConfettiController;

  @State isEditSheetShow: boolean = false;
  @State editingTask: DDLItem | null = null; // 暂存正在编辑的完整对象
  @State editingTitle: string = "";          // 绑定输入框
  @State editingNote: string = "";           // 绑定输入框

  @State editingStartTime: Date = new Date();
  @State editingEndTime: Date = new Date();

  @State inputBgColor: ResourceColor = $r('app.color.background_tertiary');

  private repo = TaskRepository.getInstance();

  @StorageLink(C.KEY_PROGRESS_DIRECTION) @Watch('loadData') progressDir: boolean = false;

  async aboutToAppear() {
    this.bindController();

    await this.loadData();
    // 监听同步完成事件，自动刷新
    getContext(this).eventHub.on('sync_done', () => {
      console.info('[Event] Received sync_done event, reloading...');
      this.loadData();
    });

    this.repo.syncNow().catch((e: Error) => console.error(e.message));
  }

  aboutToDisappear(): void {
    getContext(this).eventHub.off('sync_done');
  }

  // 绑定逻辑到 Controller
  private bindController() {
    this.controller.requestBatchComplete = (): Promise<void> => this.handleBatchComplete();
    this.controller.requestBatchArchive = (): Promise<void> => this.handleBatchArchive();
    this.controller.requestBatchDelete = (): void => this.handleBatchDelete();
    this.controller.requestBatchEdit = (): Promise<void> => this.handleBatchEdit();
    this.controller.requestExitSelection = (): void => this.exitSelectionMode();
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

    const displayProgress = this.progressDir ? progress : 1.0 - progress

    return {
      title: item.name,
      remainingTimeAlt: timeText,
      note: item.note || "",
      progress: displayProgress,
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
        this.confetti.fire();
      } else {
        targetItem.completeTime = "";
      }

      // 4. 写库 + 触发同步
      await this.repo.updateDDL(targetItem);

      // 5. 刷新 UI
      // 优化体验：这里可以直接修改 this.taskList 本地状态做乐观更新，但重新 loadData 最稳妥
      await this.loadData();

      promptAction.showToast({
        message: newStatus ? $r('app.string.toast_finished') : $r('app.string.toast_definished')
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
          this.loadData();
        },
        fontColor: $r('app.color.brand')
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            await this.repo.deleteDDL(dbId);
            await this.loadData();
            promptAction.showToast({ message: $r('app.string.toast_deletion') });
          } catch (e) {
            console.error(`Delete failed: ${e}`);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      },
      backgroundBlurStyle: BlurStyle.Thick
    })
  }

  // 进入多选模式
  private enterSelectionMode(firstId: number) {
    VibrationUtils.vibrateShort();
    this.isSelectionMode = true;
    this.selectedIds = [firstId];
  }

  // 退出多选模式
  private exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedIds = [];
  }

  // 切换单个选中状态
  private toggleSelection(dbId: number) {
    const index = this.selectedIds.indexOf(dbId);
    if (index >= 0) {
      // 已选中 -> 移除
      this.selectedIds.splice(index, 1);
      // 如果一个都没选了，是否自动退出？通常为了体验保留模式，直到点X
      if (this.selectedIds.length === 0) {
        // 可选：this.exitSelectionMode();
      }
    } else {
      // 未选中 -> 添加
      this.selectedIds.push(dbId);
    }
    // 触发 UI 更新（如果是简单的数组 push 可能需要重新赋值引用）
    this.selectedIds = [...this.selectedIds];

    if (this.selectedIds.length === 0) {
      this.exitSelectionMode();
    }
  }

  // [新增] 批量逻辑：标记完成
  private async handleBatchComplete() {
    if (this.selectedIds.length === 0) return;

    VibrationUtils.vibrateShort();
    try {
      const allItems = await this.repo.getAllDDLs();
      // 找到所有选中的项目
      const targets = allItems.filter(item => this.selectedIds.includes(item.id));

      // 更新状态
      targets.forEach(item => {
        item.isCompleted = true;
        item.completeTime = new Date().toISOString();
      });

      // 批量更新数据库 (假设 repo 支持 updateDDL，如果不支持批量，需要循环 await)
      // 建议 repo 增加 updateDDLs(items: Array<DDLItem>)
      for (const item of targets) {
        await this.repo.updateDDL(item);
      }

      promptAction.showToast({ message: `已完成 ${targets.length} 项任务` });
      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      console.error('Batch complete failed:', e);
    }
  }

  // [新增] 批量逻辑：归档
  private async handleBatchArchive() {
    if (this.selectedIds.length === 0) return;
    try {
      const allItems = await this.repo.getAllDDLs();
      const targets = allItems.filter(item => this.selectedIds.includes(item.id));

      targets.forEach(item => {
        if (item.isCompleted) item.isArchived = true;
      });

      for (const item of targets) {
        await this.repo.updateDDL(item);
      }

      promptAction.showToast({ message: `已归档 ${targets.length} 项任务` });
      this.exitSelectionMode();
      await this.loadData();
    } catch (e) {
      console.error('Batch archive failed:', e);
    }
  }

  // [新增] 批量逻辑：删除
  private handleBatchDelete() {
    if (this.selectedIds.length === 0) return;

    VibrationUtils.vibrateMedium();
    AlertDialog.show({
      title: '批量删除',
      message: `确定要删除选中的 ${this.selectedIds.length} 个任务吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      offset: { dx: 0, dy: -20 },
      primaryButton: {
        value: '取消',
        fontColor: $r('app.color.brand'),
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            for (const id of this.selectedIds) {
              await this.repo.deleteDDL(id);
            }
            promptAction.showToast({ message: '删除成功' });
            this.exitSelectionMode();
            await this.loadData();
          } catch (e) {
            console.error('Batch delete failed:', e);
          }
        }
      },
      backgroundBlurStyle: BlurStyle.Regular
    });
  }

  private async handleBatchEdit() {
    if (this.selectedIds.length === 0) {
      promptAction.showToast({ message: '未选中任何任务' });
      return;
    }
    const targetId = this.selectedIds[0];
    try {
      const allItems = await this.repo.getAllDDLs();
      const target = allItems.find(item => item.id === targetId);

      if (target) {
        this.editingTask = target;
        this.editingTitle = target.name;
        this.editingNote = target.note || "";

        // 🔥 解析时间字符串为 Date 对象
        this.editingStartTime = target.startTime ? new Date(target.startTime) : new Date();
        this.editingEndTime = target.endTime ? new Date(target.endTime) : new Date();

        this.isEditSheetShow = true;
        this.exitSelectionMode();
      } else {
        promptAction.showToast({ message: '找不到该任务' });
      }
    } catch (e) {
      console.error('Fetch task for edit failed:', e);
      promptAction.showToast({ message: '无法打开编辑' });
    }
  }

  private async saveEdit() {
    if (!this.editingTask) return;
    if (!this.editingTitle.trim()) {
      promptAction.showToast({ message: '任务名称不能为空' });
      return;
    }

    try {
      // 🔥 ISO 时间转换逻辑 (复用自 AddTaskPage)
      const toLocalISO = (d: Date) => {
        const offset = d.getTimezoneOffset() * 60000;
        const local = new Date(d.getTime() - offset);
        return local.toISOString().slice(0, 19);
      };

      this.editingTask.name = this.editingTitle;
      this.editingTask.note = this.editingNote;
      this.editingTask.startTime = toLocalISO(this.editingStartTime);
      this.editingTask.endTime = toLocalISO(this.editingEndTime);

      await this.repo.updateDDL(this.editingTask);

      this.isEditSheetShow = false;
      await this.loadData();
      promptAction.showToast({ message: '修改已保存' });

    } catch (e) {
      console.error('Save edit failed:', e);
      promptAction.showToast({ message: '保存失败' });
    }
  }

  private formatTime(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private showTimePicker(isStart: boolean) {
    DatePickerDialog.show({
      start: new Date("2000-1-1"),
      end: new Date("2100-12-31"),
      selected: isStart ? this.editingStartTime : this.editingEndTime,
      onAccept: (value: DatePickerResult) => {
        const selectedDate = new Date(value.year!, value.month!, value.day!);
        TimePickerDialog.show({
          selected: isStart ? this.editingStartTime : this.editingEndTime,
          useMilitaryTime: true,
          onAccept: (timeValue: TimePickerResult) => {
            selectedDate.setHours(timeValue.hour, timeValue.minute);
            if (isStart) {
              this.editingStartTime = selectedDate;
            } else {
              this.editingEndTime = selectedDate;
            }
          },
          backgroundBlurStyle: BlurStyle.Regular,
          selectedTextStyle: {
            color: $r('app.color.brand')
          },
          acceptButtonStyle: {
            fontColor: $r('app.color.brand')
          },
          cancelButtonStyle: {
            fontColor: $r('app.color.brand')
          }
        })
      },
      backgroundBlurStyle: BlurStyle.Regular,
      selectedTextStyle: {
        color: $r('app.color.brand')
      },
      acceptButtonStyle: {
        fontColor: $r('app.color.brand')
      },
      cancelButtonStyle: {
        fontColor: $r('app.color.brand')
      }
    })
  }

  @Builder
  taskEditSheet() {
    Column() {
      Column({ space: 16 }) {

        // 任务名称
        TextInput({ placeholder: '任务名称', text: this.editingTitle })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.editingTitle = val;
          })

        // 开始时间
        TimeInputButton({
          title: '开始时间',
          content: this.formatTime(this.editingStartTime),
          onClickButton: (): void => this.showTimePicker(true)
        })

        // 结束时间
        TimeInputButton({
          title: '结束',
          content: this.formatTime(this.editingEndTime),
          onClickButton: (): void => this.showTimePicker(false)
        })

        // 备注
        TextArea({ placeholder: '备注 (可选)', text: this.editingNote })
          .height(120)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.editingNote = val;
          })
          .enableKeyboardOnFocus(false) // 防止Sheet一打开键盘就弹起遮挡

        Button('保存').onClick((event: ClickEvent) => {
          this.saveEdit();
        })
          .width('100%')
          .backgroundColor($r('app.color.brand'))

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
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

                      // 多选 Props
                      selectionMode: this.isSelectionMode,
                      selected: this.selectedIds.includes(item.dbId),

                      // 普通交互
                      onComplete: async () => { this.handleComplete(item.dbId) },
                      onDelete: async () => { this.handleDelete(item.dbId, item.title) },

                      // 多选交互
                      onLongPressSelect: () => {
                        if (!this.isSelectionMode) {
                          this.enterSelectionMode(item.dbId);
                        }
                      },
                      onToggleSelect: () => {
                        this.toggleSelection(item.dbId);
                      }
                    })
                  }
                }, (item: TaskUIModel) => `${item.dbId}_${item.status}_${item.progress}`)

                ListItem() {
                  Divider().color(Color.Transparent).height(80).width('100%')
                }
              }
              .width("100%")
              .height("100%") // 撑满 TopSafeContainer 的剩余空间
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
    .bindSheet($$this.isEditSheetShow, this.taskEditSheet(), {
      height: SheetSize.FIT_CONTENT, // 半屏高度，也可以自定义高度
      dragBar: true,            // 显示拖拽条
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.editingTask = null; // 清理数据
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: '编辑任务',
        subtitle: '修改任务信息。'
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP])
  }
}