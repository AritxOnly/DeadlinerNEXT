import { TopSafeContainer } from "../../components/TopSafeContainer"
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus, HabitStatus } from '../../../model/DDLModels';
import { HabitCircleProgress, WeekRow, HabitRow, DDLStatus, HabitWithDailyStatus, DayOverview } from '../../components/HabitComponents'
import { HabitListController } from "./HabitListController";
import { ChipGroup, ChipGroupItemOptions, ChipSize, promptAction } from '@kit.ArkUI'
import { VibrationUtils } from "../../../utils/VibrationUtils";
import { ConfettiController } from "../../components/confetti/ConfettiController";

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
  }

  // —— 3. 业务逻辑 ——

  async refreshAll(date: Date) {
    const allHabits = await this.repo.getAllHabits();

    // 计算列表状态
    const statusList = await Promise.all(allHabits.map(h => this.buildStatusForDate(h, date)));
    this.allHabitsCache = statusList;
    this.applyFilter();

    // 计算周视图
    this.calculateWeekOverview(date, allHabits);
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
    this.prepareEditData(targetItem.habit);
  }

  private prepareEditData(habit: Habit) {
    // 基础信息
    this.editingHabitId = habit.id;
    this.editingHabitName = habit.name;

    // 周期：枚举 -> 索引
    // 这里的顺序必须与 periodOptions 数组一致: [DAILY, WEEKLY, MONTHLY]
    const pMap = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY];
    const pIndex = pMap.indexOf(habit.period);
    // 如果找不到(比如数据错误)，默认选第一个(DAILY)
    this.editingPeriodIndex = [pIndex !== -1 ? pIndex : 0];

    // 目标类型：枚举 -> 索引
    // 这里的顺序必须与 goalTypeOptions 数组一致: [PER_PERIOD, TOTAL]
    const gMap = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];
    const gIndex = gMap.indexOf(habit.goalType);
    this.editingGoalTypeIndex = [gIndex !== -1 ? gIndex : 0];

    // 数字转字符串
    this.editingTimesPerPeriod = habit.timesPerPeriod.toString();
    this.editingTotalTarget = habit.totalTarget ? habit.totalTarget.toString() : "";

    // 打开 Sheet
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

  @State inputBgColor: ResourceColor = $r('app.color.background_tertiary')

  @State editingHabitId: number = -1;
  @State editingHabitName: string = '';

  @State editingPeriodIndex: number[] = [0];
  @State editingGoalTypeIndex: number[] = [0];

  @State editingTimesPerPeriod: string = '1';
  @State editingTotalTarget: string = '';

  private periodOptions: ChipGroupItemOptions[] = [
    { label: { text: "每日" } },
    { label: { text: "每周" } },
    { label: { text: "每月" } }
  ];

  private goalTypeOptions: ChipGroupItemOptions[] = [
    { label: { text: "坚持" } },
    { label: { text: "定量" } }
  ];

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
    Column() {
      Column({ space: 16 }) {

        // 1. 习惯名称
        TextInput({ placeholder: '习惯名称', text: this.editingHabitName })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.editingHabitName = val;
          })

        // 2. 周期选择 (ChipGroup)
        Column({ space: 8 }) {
          Text("重复周期")
            .fontSize(14)
            .fontColor(Color.Gray)
            .padding({ left: 4 })

          ChipGroup({
            items: this.periodOptions,
            itemStyle: {
              size: ChipSize.NORMAL,
              backgroundColor: this.inputBgColor,
              fontColor: Color.Gray,
              selectedBackgroundColor: $r('app.color.brand'),
              selectedFontColor: Color.White
            },
            selectedIndexes: this.editingPeriodIndex,
            onChange: (indexes: number[]) => {
              this.editingPeriodIndex = indexes;
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 3. 目标设置 (Row 布局)
        Row({ space: 12 }) {
          // 左侧：频率次数
          Column({ space: 8 }) {
            Text("每次/频次")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })

            TextInput({ placeholder: '1', text: this.editingTimesPerPeriod })
              .type(InputType.Number)
              .height(ITEM_HEIGHT)
              .fontSize(16)
              .backgroundColor(this.inputBgColor)
              .borderRadius(COMMON_RADIUS)
              .padding({ left: 16, right: 16 })
              .width('100%')
              .onChange((val) => {
                this.editingTimesPerPeriod = val;
              })
          }
          .layoutWeight(1)

          // 右侧：目标类型
          Column({ space: 8 }) {
            Text("目标类型")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })

            ChipGroup({
              items: this.goalTypeOptions,
              itemStyle: {
                size: ChipSize.NORMAL,
                backgroundColor: this.inputBgColor,
                fontColor: Color.Gray,
                selectedBackgroundColor: $r('app.color.brand'),
                selectedFontColor: Color.White
              },
              selectedIndexes: this.editingGoalTypeIndex,
              onChange: (indexes: number[]) => {
                this.editingGoalTypeIndex = indexes;
              }
            })
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 4. 总目标输入框 (动态显示)
        if (this.editingGoalTypeIndex.length > 0 &&
          this.getGoalTypeFromIndex(this.editingGoalTypeIndex[0]) === HabitGoalType.TOTAL) {
          Column({ space: 8 }) {
            Text("总目标数量")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })

            TextInput({ placeholder: '例如：100 (页/次)', text: this.editingTotalTarget })
              .type(InputType.Number)
              .height(ITEM_HEIGHT)
              .fontSize(16)
              .backgroundColor(this.inputBgColor)
              .borderRadius(COMMON_RADIUS)
              .padding({ left: 16, right: 16 })
              .width('100%')
              .onChange((val) => {
                this.editingTotalTarget = val;
              })
          }
          .width('100%')
        }

        Button('保存').onClick((event: ClickEvent) => {
          this.saveHabitEdit();
        })
          .width('100%')
          .backgroundColor($r('app.color.brand'))

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 }) // 稍微增加顶部padding
  }

  // —— 保存编辑逻辑 ——
  private async saveHabitEdit() {
    // 1. 基础校验
    if (!this.editingHabitName.trim()) {
      promptAction.showToast({ message: '请输入习惯名称' });
      return;
    }

    const times = parseInt(this.editingTimesPerPeriod);
    if (isNaN(times) || times <= 0) {
      promptAction.showToast({ message: '请输入有效的单次目标' });
      return;
    }

    // 2. 获取枚举值
    // 防御性编程：确保数组不为空
    const pIndex = this.editingPeriodIndex.length > 0 ? this.editingPeriodIndex[0] : 0;
    const gIndex = this.editingGoalTypeIndex.length > 0 ? this.editingGoalTypeIndex[0] : 0;

    const newPeriod = this.getPeriodFromIndex(pIndex); // 需要确保组件内有这个 helper
    const newGoalType = this.getGoalTypeFromIndex(gIndex); // 需要确保组件内有这个 helper

    // 3. 校验总目标 (如果是 TOTAL 类型)
    let total: number | null = null;
    if (newGoalType === HabitGoalType.TOTAL) {
      total = parseInt(this.editingTotalTarget);
      if (isNaN(total) || total <= 0) {
        promptAction.showToast({ message: '请输入有效的总目标' });
        return;
      }
    }

    try {
      // 4. 获取原始对象并更新
      // 我们需要先从缓存或Repo里拿到完整的 Habit 对象，因为 update 需要 id, ddlId, createdAt 等字段
      // 假设我们通过 editingHabitId 能找到它
      const originalItem = this.allHabitsCache.find(it => it.habit.id === this.editingHabitId);

      if (!originalItem) {
        promptAction.showToast({ message: '未找到原始习惯数据' });
        return;
      }

      const originalHabit = originalItem.habit;

      // 构建更新后的对象
      const updatedHabit: Habit = {
        id: originalHabit.id,
        ddlId: originalHabit.ddlId,
        name: this.editingHabitName,
        description: "",
        color: originalHabit.color,
        iconKey: originalHabit.iconKey,
        period: newPeriod,
        timesPerPeriod: times,
        goalType: newGoalType,
        totalTarget: total,
        createdAt: originalHabit.createdAt,
        updatedAt: new Date().toISOString(),
        status: originalHabit.status,
        sortOrder: originalHabit.sortOrder,
        alarmTime: originalHabit.alarmTime
      };

      // 5. 执行数据库更新
      await this.repo.updateHabit(updatedHabit);

      // (可选) 如果你的 DDL 表也存储了 Name/Note 用于搜索，也需要更新 DDL 表
      // 比如: await DatabaseHelper.getInstance().updateDDLNameAndNote(updatedHabit.ddlId, updatedHabit.name, updatedHabit.description);

      // 6. 收尾工作
      promptAction.showToast({ message: '修改成功' });

      // 关闭 Sheet (假设你用 isEditSheetShow 控制)
      this.isEditSheetShow = false;

      // 刷新列表
      await this.refreshAll(this.selectedDate);

      // 通知全局 (如果需要)
      getContext(this).eventHub.emit('sync_done');

    } catch (e) {
      console.error(`Update habit failed: ${e}`);
      promptAction.showToast({ message: '修改失败' });
    }
  }

  @State isRefreshing: boolean = false;

  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight, scrollable: false }) {
        Column() {
          // 1. 顶部进度 (使用新组件)
          HabitCircleProgress({ progress: this.getTodayCompletionRatio() })
            .margin({ top: 12, bottom: 12 })

          // 2. 本周日期横条 (使用新组件)
          WeekRow({
            weekOverview: this.weekOverview,
            selectedDate: this.selectedDate,
            onSelectDate: (d: Date): void => this.onDateSelected(d)
          })
            .margin({ bottom: 8 })
            .width('100%')

          Refresh({
            refreshing: $$this.isRefreshing
          }) {
            List({ scroller: this.scroller, space: 10 }) {
              ForEach(this.displayHabits, (item: HabitWithDailyStatus) => {
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
              }, (item: HabitWithDailyStatus) => {
                return `${item.habit.id}_${item.doneCount}_${item.habit.updatedAt}`;
              })
            }
            .width('100%')
            .height("100%")
            .layoutWeight(1)
            .padding({ left: 12, right: 12, bottom: 96 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          }
          .onRefreshing(async () => {
            this.isRefreshing = true

            await this.refreshAll(this.selectedDate);
            this.isRefreshing = false;
          })
        }
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isEditSheetShow, this.habitEditSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.editingHabitId = -1;
        this.editingHabitName = '';
        this.editingPeriodIndex = [];
        this.editingGoalTypeIndex = [];
        this.editingTimesPerPeriod = '';
        this.editingTotalTarget = '';
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