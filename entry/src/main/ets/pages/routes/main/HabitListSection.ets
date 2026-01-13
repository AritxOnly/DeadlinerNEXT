import { TopSafeContainer } from "../../components/TopSafeContainer"
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus, HabitStatus } from '../../../model/DDLModels';
import { HabitCircleProgress, WeekRow, HabitRow, DDLStatus, HabitWithDailyStatus, DayOverview } from '../../components/HabitComponents'
import { HabitListController } from "./HabitListController";
import { ChipGroup, ChipGroupItemOptions, ChipSize, promptAction } from '@kit.ArkUI'
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { ConfettiController } from "../../components/confetti/ConfettiController";
import { FloatUpModifier } from "../../../utils/animation/FloatUpModifier";
import { HabitEditSheet } from "./modify/HabitEditSheet";
import { HabitReminderDialog } from "../../components/HabitReminderDialog";
import { ReminderScheduler } from "../../../utils/notification/ReminderScheduler";

const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct HabitListSection {
  @Prop topAvoidHeight: number = 0;

  scroller: Scroller = new Scroller();
  confetti: ConfettiController = new ConfettiController();
  controller: HabitListController = new HabitListController();

  // —— 1. 数据源 (@State) ——
  @State selectedDate: Date = new Date();
  @State searchQuery: string = "";
  @State weekOverview: DayOverview[] = [];
  @State displayHabits: HabitWithDailyStatus[] = [];

  // 内存缓存
  private allHabitsCache: HabitWithDailyStatus[] = [];

  // 交互模式状态（对应 selectionMode）
  @Link isSelectionMode: boolean;
  @State selectedDdlIds: Set<number> = new Set();

  private repo = HabitRepository.getInstance();

  @State tempHabitName: string = "";
  @State tempIsEnabled: boolean = false;
  @State tempSelectedTime: Date = new Date();
  @State currentAlarmDdlId: number = -1;

  // 定义 CustomDialogController
  alarmDialogController: CustomDialogController = new CustomDialogController({
    builder: HabitReminderDialog({
      habitName: this.tempHabitName,
      isEnabled: this.tempIsEnabled,
      selectedTime: this.tempSelectedTime,
      onConfirm: (enabled, timeStr): Promise<void> => this.saveAlarmSetting(enabled, timeStr)
    }),
    // 修改点：设置为居中
    alignment: DialogAlignment.Center,
    // 居中时通常不需要 offset，除非你想微调
    offset: { dx: 0, dy: 0 },
    autoCancel: true,
    customStyle: true
  });

  // —— 2. 生命周期 ——
  aboutToAppear() {
    this.refreshAll(this.selectedDate);

    if (this.controller) {
      this.bindController();
    }

    getContext(this).eventHub.on('sync_done', this.onSyncEvent);
  }

  aboutToDisappear() {
    getContext(this).eventHub.off('sync_done', this.onSyncEvent);
  }

  private onSyncEvent = () => {
    console.debug('HabitListSection received sync_done event');
    this.refreshAll(this.selectedDate);
  }

  private bindController() {
    this.controller.requestBatchComplete = (): Promise<void> => this.handleBatchComplete();
    this.controller.requestBatchArchive = (): Promise<void> => this.handleBatchArchive();
    this.controller.requestBatchDelete = (): Promise<void> => this.handleBatchDelete();
    this.controller.requestBatchEdit = (): void => this.handleBatchEdit();
    this.controller.requestExitSelection = (): void => this.exitSelectionMode();
    this.controller.requestSetAlarm = (): Promise<void> => this.handleRequestSetAlarm();
    this.controller.loadData = (): Promise<void> => this.refreshAll(this.selectedDate);
  }

  /**
   * 处理设置提醒的请求
   * 逻辑：检查当前是否选中了【唯一】的一个习惯，如果是，则弹出设置框
   */
  async handleRequestSetAlarm() {
    // 1. 校验选中数量
    if (this.selectedDdlIds.size !== 1) {
      promptAction.showToast({ message: '请选择一个习惯来设置提醒' });
      return;
    }

    const ddlId = Array.from(this.selectedDdlIds)[0];
    this.currentAlarmDdlId = ddlId;

    // 2. 获取习惯数据
    const item = this.allHabitsCache.find(it => it.habit.ddlId === ddlId);
    if (!item) return;
    const habit = item.habit;

    // 3. 准备弹窗数据 (对应 Android 中的 try-catch 解析逻辑)
    this.tempHabitName = habit.name;

    if (habit.alarmTime && habit.alarmTime.length > 0) {
      this.tempIsEnabled = true;
      // 解析 "HH:mm"
      const parts = habit.alarmTime.split(':');
      const d = new Date();
      d.setHours(parseInt(parts[0]), parseInt(parts[1]));
      this.tempSelectedTime = d;
    } else {
      this.tempIsEnabled = false;
      // 默认时间 20:00
      const d = new Date();
      d.setHours(20, 0);
      this.tempSelectedTime = d;
    }

    // 4. 打开弹窗
    this.alarmDialogController.open();

    // 5. 可选：退出选择模式 (根据交互设计决定，Android 代码未退出，这里建议保留选择状态或退出均可)
    // this.exitSelectionMode();
  }

  /**
   * 保存提醒设置 (对应 Android 的 onPositiveButton)
   */
  async saveAlarmSetting(enabled: boolean, timeStr: string) {
    if (this.currentAlarmDdlId === -1) return;

    try {
      // 1. 从库中重新获取最新对象 (防止并发修改)
      const habitRaw = await this.repo.getHabitByDdlId(this.currentAlarmDdlId);
      if (!habitRaw) return;

      // 2. 更新对象
      // 如果 enabled 为 true，保存 timeStr (例如 "20:00")，否则为 null
      const updatedHabit = habitRaw; // 注意：直接修改引用或 clone
      updatedHabit.alarmTime = enabled ? timeStr : null; // ArkTS 中如果类型定义是 string | null

      await this.repo.updateHabit(updatedHabit);

      // 3. 触发调度器刷新
      const allHabits = await this.repo.getAllHabits();
      await ReminderScheduler.refreshHabits(allHabits);

      // 4. 界面反馈
      promptAction.showToast({ message: enabled ? `已设置提醒: ${timeStr}` : '提醒已关闭' });

      // 刷新列表显示（虽然 alarmTime 可能不显示在列表上，但保持数据一致性）
      await this.refreshAll(this.selectedDate);

      // 退出选择模式
      this.exitSelectionMode();

    } catch (e) {
      console.error('Set alarm failed:', e);
      promptAction.showToast({ message: '设置失败' });
    }
  }

  @State isFirstLoad: boolean = true;

  async refreshAll(date: Date) {
    const allHabitsRaw = await this.repo.getAllHabits();
    const allHabits = allHabitsRaw.filter(h => h.status !== HabitStatus.ARCHIVED);

    // 计算列表状态
    const statusList = await Promise.all(allHabits.map(h => this.buildStatusForDate(h, date)));
    this.allHabitsCache = statusList;
    this.applyFilter();

    // 计算周视图
    this.calculateWeekOverview(date, allHabits);

    if (this.isFirstLoad) {
      setTimeout(() => {
        this.isFirstLoad = false;
      }, 750)
    }
  }

  private async buildStatusForDate(habit: Habit, date: Date): Promise<HabitWithDailyStatus> {
    const GeneratedDestructArray_1 = this.getPeriodBounds(habit.period, date);
    const start = GeneratedDestructArray_1[0];
    const end = GeneratedDestructArray_1[1];
    const queryStart = habit.goalType === HabitGoalType.TOTAL ? new Date(0) : start;
    const queryEnd = habit.goalType === HabitGoalType.TOTAL ? date : end;

    const records = await this.repo.getRecordsForHabitInRange(habit.id, queryStart, queryEnd);

    const done = records
      .filter(r => r.status === HabitRecordStatus.COMPLETED)
      .reduce((sum, r) => sum + r.count, 0);

    let target = Math.max(1, habit.timesPerPeriod);
    if (habit.goalType === HabitGoalType.TOTAL) {
      target = habit.totalTarget ? Math.max(1, habit.totalTarget) : Math.max(1, done);
    }

    return {
      habit: habit,
      doneCount: done,
      targetCount: target,
      isCompleted: habit.totalTarget ? done >= habit.totalTarget : done >= target
    };
  }

  private applyFilter() {
    if (!this.searchQuery || this.searchQuery.trim() === "") {
      this.displayHabits = this.allHabitsCache;
    } else {
      const lowerQ = this.searchQuery.toLowerCase();
      this.displayHabits = this.allHabitsCache.filter(it =>
      it.habit.name.toLowerCase().includes(lowerQ)
      );
    }
  }

  // 日期辅助逻辑
  private getPeriodBounds(period: HabitPeriod, date: Date): [Date, Date] {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);

    if (period === HabitPeriod.DAILY) {
      return [d, d];
    } else if (period === HabitPeriod.WEEKLY) {
      const day = d.getDay();
      const diff = d.getDate() - day + (day === 0 ? -6 : 1);
      const monday = new Date(d.setDate(diff));
      const sunday = new Date(monday);
      sunday.setDate(monday.getDate() + 6);
      return [monday, sunday];
    } else if (period === HabitPeriod.MONTHLY) {
      const firstDay = new Date(d.getFullYear(), d.getMonth(), 1);
      const lastDay = new Date(d.getFullYear(), d.getMonth() + 1, 0);
      return [firstDay, lastDay];
    }
    return [d, d];
  }

  private async calculateWeekOverview(centerDate: Date, allHabits: Habit[]) {
    const d = new Date(centerDate);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(d.setDate(diff));

    const week: DayOverview[] = [];
    for (let i = 0; i < 7; i++) {
      const current = new Date(monday);
      current.setDate(monday.getDate() + i);

      // 简化计算：实际项目可能需要优化性能
      const statuses = await Promise.all(allHabits.map(h => this.buildStatusForDate(h, current)));
      const completedCount = statuses.filter(s => s.isCompleted).length;
      const totalCount = allHabits.length;

      week.push({
        date: current,
        completedCount: completedCount,
        totalCount: totalCount,
        completionRatio: totalCount > 0 ? (completedCount / totalCount) : 0
      });
    }
    this.weekOverview = week;
  }

  // —— 4. 交互事件 ——

  onDateSelected(date: Date) {
    this.selectedDate = date;
    this.refreshAll(date);
  }

  async onToggleHabit(item: HabitWithDailyStatus) {
    // 只有选中的日期不晚于今天才能打卡
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const currentSel = new Date(this.selectedDate);
    currentSel.setHours(0, 0, 0, 0);

    if (currentSel.getTime() > today.getTime()) {
      return; // 未来日期不可打卡
    }

    if (this.isSelectionMode) {
      this.toggleSelection(item.habit.ddlId);
      return;
    }

    VibrationUtils.vibrateShort();

    const beforeRate = item.doneCount / item.targetCount;
    await this.repo.toggleRecord(item.habit.id, this.selectedDate);
    await this.refreshAll(this.selectedDate);

    // 庆祝检测
    const afterItem = this.allHabitsCache.find(it => it.habit.id === item.habit.id);
    if (afterItem) {
      const afterRate = afterItem.doneCount / afterItem.targetCount;
      if (beforeRate < 1 && afterRate >= 1) {
        console.info("🎉 Habit Completed!");
        this.confetti.fire();
      }
    }
  }

  exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedDdlIds.clear();
  }

  async handleBatchComplete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateShort();
    // 筛选出选中的、且当天还【未完成】的习惯
    // 注意：allHabitsCache 里存的是 HabitWithDailyStatus，包含 ddlId
    const targets = this.allHabitsCache.filter(item =>
    this.selectedDdlIds.has(item.habit.ddlId) && !item.isCompleted
    );

    if (targets.length === 0) {
      promptAction.showToast({ message: '选中的习惯已全部完成' });
      this.exitSelectionMode();
      return;
    }

    try {
      // 并行执行插入记录
      // 注意：这里简单地插入一条记录。如果需要精确控制次数（比如目标是3次，现在是0次，是否直接加满？），
      // 目前逻辑是 insertRecord 默认 count=1。
      // 如果你的“批量完成”定义是“直接设为达标”，你需要计算缺多少次。
      // 这里简化为：直接补齐到目标次数 (或者简单地加一次，视你的业务定义而定)
      // 假设业务定义：批量打卡 = 给选中的每一项加一次打卡
      await Promise.all(targets.map(item => {
        return this.repo.insertRecord(item.habit.id, this.selectedDate, 1);
      }));

      promptAction.showToast({ message: `已打卡 ${targets.length} 个习惯` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      console.error('Batch complete failed:', e);
      promptAction.showToast({ message: '操作失败' });
    }
  }

  async handleBatchDelete() {
    if (this.selectedDdlIds.size === 0) return;

    VibrationUtils.vibrateMedium();
    // 弹窗确认
    AlertDialog.show({
      title: '删除习惯',
      message: `确定要删除选中的 ${this.selectedDdlIds.size} 个习惯吗？此操作不可恢复。`,
      autoCancel: true, // 点击遮罩层是否关闭
      alignment: DialogAlignment.Bottom, // 弹窗位置
      offset: { dx: 0, dy: -20 }, // 微调位置
      gridCount: 4, // 弹窗宽度占用栅格数
      backgroundBlurStyle: BlurStyle.Regular,
      primaryButton: {
        value: '取消',
        fontColor: $r('app.color.brand'), // 你的主题色
        action: () => {
          // 点击取消，不做任何事，或者可以退出选择模式
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          // 点击删除
          try {
            const idsToDelete = Array.from(this.selectedDdlIds);
            await Promise.all(idsToDelete.map(ddlId => this.repo.deleteHabitByDdlId(ddlId)));

            promptAction.showToast({ message: '删除成功' });
            this.refreshAll(this.selectedDate);
            this.exitSelectionMode();
            // 通知全局刷新
            getContext(this).eventHub.emit('sync_done');
          } catch (e) {
            console.error('Batch delete failed:', e);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    })
  }

  async handleBatchArchive() {
    if (this.selectedDdlIds.size === 0) return;

    try {
      const targets = this.allHabitsCache.filter(item => this.selectedDdlIds.has(item.habit.ddlId));

      await Promise.all(targets.map(item => {
        // 更新状态为 ARCHIVED
        const updatedHabit = item.habit;
        updatedHabit.status = HabitStatus.ARCHIVED;
        return this.repo.updateHabit(updatedHabit);
      }));

      promptAction.showToast({ message: `已归档 ${targets.length} 个习惯` });
      this.refreshAll(this.selectedDate);
      this.exitSelectionMode();
    } catch (e) {
      console.error('Batch archive failed:', e);
      promptAction.showToast({ message: '归档失败' });
    }
  }

  handleBatchEdit() {
    if (this.selectedDdlIds.size === 0) {
      promptAction.showToast({ message: '未选中任何习惯' });
      return;
    }

    const ddlId: number = this.selectedDdlIds.values().next().value;

    const targetItem = this.allHabitsCache.find(it => it.habit.ddlId === ddlId);

    if (!targetItem) {
      promptAction.showToast({ message: '未找到习惯数据' });
      return;
    }

    // 5. 退出选择模式
    this.exitSelectionMode();

    // 6. 填充数据并打开编辑页
    this.currentEditingHabit = targetItem.habit;
    this.isEditSheetShow = true;
  }

  onLongPress(ddlId: number) {
    VibrationUtils.vibrateShort();
    this.isSelectionMode = true;
    this.toggleSelection(ddlId);
  }

  toggleSelection(ddlId: number) {
    if (this.selectedDdlIds.has(ddlId)) {
      this.selectedDdlIds.delete(ddlId);
      // 如果所有都取消了，可能需要退出选择模式，视需求而定
      if (this.selectedDdlIds.size === 0) {
        this.isSelectionMode = false;
      }
    } else {
      this.selectedDdlIds.add(ddlId);
    }
  }

  isSelected(ddlId: number): boolean {
    return this.selectedDdlIds.has(ddlId);
  }

  private getTodayCompletionRatio(): number {
    const todayOverview = this.weekOverview.find(
      d => d.date.toDateString() === this.selectedDate.toDateString()
    );
    return todayOverview ? todayOverview.completionRatio : 0;
  }

  // == 编辑表单 ==
  @State isEditSheetShow: boolean = false
  @State currentEditingHabit: Habit | undefined = undefined;

  // —— 辅助函数 ——
  private getGoalTypeFromIndex(index: number): HabitGoalType {
    const map = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];
    return map[index] || HabitGoalType.PER_PERIOD;
  }

  private getPeriodFromIndex(index: number): HabitPeriod {
    const map = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY];
    return map[index] || HabitPeriod.DAILY;
  }

  @Builder
  habitEditSheet() {
    HabitEditSheet({
      isShow: $isEditSheetShow,
      editingHabit: this.currentEditingHabit,
      onSave: (habit): Promise<void> => this.handleSaveHabit(habit)
    })
  }

  async handleSaveHabit(updatedHabit: Habit) {
    // 执行数据库更新
    await this.repo.updateHabit(updatedHabit);
    // 刷新列表
    await this.refreshAll(this.selectedDate);
    // 全局通知
    getContext(this).eventHub.emit('sync_done');
  }

  @State isRefreshing: boolean = false;

  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight, scrollable: false }) {
        Column() {
          // 1. 顶部进度 (使用新组件)
          HabitCircleProgress({ progress: this.getTodayCompletionRatio() })
            .margin({ top: 12, bottom: 12 })
            .align(Alignment.Center)
            .attributeModifier(new FloatUpModifier(0, 15, this.isFirstLoad))

          // 2. 本周日期横条 (使用新组件)
          WeekRow({
            weekOverview: this.weekOverview,
            selectedDate: this.selectedDate,
            onSelectDate: (d: Date): void => this.onDateSelected(d)
          })
            .margin({ bottom: 8 })
            .align(Alignment.Center)
            .attributeModifier(new FloatUpModifier(0, 15, this.isFirstLoad))

          Refresh({
            refreshing: $$this.isRefreshing
          }) {
            List({ scroller: this.scroller, space: 10 }) {
              ForEach(this.displayHabits, (item: HabitWithDailyStatus, index: number) => {
                ListItem() {
                  // 使用新组件 HabitRow
                  HabitRow({
                    data: item,
                    status: item.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO,
                    isSelected: this.isSelected(item.habit.ddlId),
                    canToggle: new Date(this.selectedDate).setHours(0, 0, 0, 0) <= new Date().setHours(0, 0, 0, 0),
                    remainingText: "",
                    onToggle: (): Promise<void> => this.onToggleHabit(item),
                    onLongPress: (): void => this.onLongPress(item.habit.ddlId)
                  })
                }
                .attributeModifier(new FloatUpModifier(index + 1, 15, this.isFirstLoad))
              }, (item: HabitWithDailyStatus) => {
                return `${item.habit.id}_${item.doneCount}_${item.habit.updatedAt}`;
              })

              ListItem() {
                Column() {
                  Blank().height(140)
                }
              }
            }
            .width('100%')
            .height('100%')
            .layoutWeight(1)
            .padding({ left: 12, right: 12 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          }
          .onRefreshing(async () => {
            this.isRefreshing = true

            await this.refreshAll(this.selectedDate);
            this.isRefreshing = false;
          })
          .layoutWeight(1)
          .width('100%')
        }
        .height('100%')
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isEditSheetShow, this.habitEditSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.currentEditingHabit = undefined;
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: '编辑习惯',
        subtitle: '修改习惯信息。'
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}