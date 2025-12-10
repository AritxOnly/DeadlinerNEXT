import { TopSafeContainer } from "../../components/TopSafeContainer"
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus, HabitStatus } from '../../../model/DDLModels';
import { HabitCircleProgress, WeekRow, HabitRow, DDLStatus, HabitWithDailyStatus, DayOverview } from '../../components/HabitComponents'
import { HabitListController } from "./HabitListController";
import { promptAction } from '@kit.ArkUI'
import { VibrationUtils } from "../../../utils/VibrationUtils";

@Component
export struct HabitListSection {
  @Prop topAvoidHeight: number = 0;

  scroller: Scroller = new Scroller();
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

    const beforeRate = item.doneCount / item.targetCount;
    await this.repo.toggleRecord(item.habit.id, this.selectedDate);
    await this.refreshAll(this.selectedDate);

    // 庆祝检测
    const afterItem = this.allHabitsCache.find(it => it.habit.id === item.habit.id);
    if (afterItem) {
      const afterRate = afterItem.doneCount / afterItem.targetCount;
      if (beforeRate < 1 && afterRate >= 1) {
        console.info("🎉 Habit Completed!");
      }
    }
  }

  exitSelectionMode() {
    this.isSelectionMode = false;
    this.selectedDdlIds.clear();
  }

  async handleBatchComplete() {
    if (this.selectedDdlIds.size === 0) return;

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
    if (this.selectedDdlIds.size === 0) return;

    if (this.selectedDdlIds.size > 1) {
      promptAction.showToast({ message: '一次只能编辑一个习惯' });
      return;
    }

    // 获取选中的 ID
    const ddlId: number = this.selectedDdlIds.values().next().value;

    // 退出选择模式
    this.exitSelectionMode();

    // TODO: 跳转到编辑页
    // 这里假设你有一个 EditHabitPage，需要通过 router 或 navPathStack 跳转
    // 假设已经在 MainHomePage 通过 AppStorage 存了 NavPathStack，或者通过 EventHub 发送
    promptAction.showToast({ message: '编辑功能开发中...' });
    // 示例： this.pageStack.pushPath({ name: 'editHabit', param: { ddlId } })
  }

  onLongPress(ddlId: number) {
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

  // —— 5. UI 构建 (HabitDisplayLayout 逻辑) ——
  build() {
    Column() {
      TopSafeContainer({ topAvoidHeight: this.topAvoidHeight }) {
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

          // 3. 习惯列表
          List({ scroller: this.scroller, space: 10 }) {
            ForEach(this.displayHabits, (item: HabitWithDailyStatus) => {
              ListItem() {
                // 使用新组件 HabitRow
                HabitRow({
                  data: item,
                  status: item.isCompleted ? DDLStatus.COMPLETED : DDLStatus.UNDERGO, // 简单映射，实际可计算 DDL 剩余时间映射状态
                  isSelected: this.isSelected(item.habit.ddlId),
                  canToggle: new Date(this.selectedDate).setHours(0,0,0,0) <= new Date().setHours(0,0,0,0),
                  remainingText: "", // 暂时留空或根据逻辑计算
                  onToggle: (): Promise<void> => this.onToggleHabit(item),
                  onLongPress: (): void => this.onLongPress(item.habit.ddlId)
                })
              }
            }, (item: HabitWithDailyStatus) => item.habit.id.toString() + "_" + item.doneCount)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, bottom: 96 })
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}

// —— 6. 占位组件 (后续替换) ——

@Component
struct PlaceholderHabitCircleProgress {
  @Prop progress: number;
  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Ring })
        .width(80).height(80)
        .color(Color.Blue)
        .style({ strokeWidth: 8 })
      Text(`${(this.progress * 100).toFixed(0)}%`)
        .fontSize(16)
    }
    .backgroundColor('#F0F0F0') // 方便调试看区域
    .borderRadius(12)
  }
}

@Component
struct PlaceholderWeekRow {
  @Prop weekOverview: DayOverview[];
  @Prop selectedDate: Date;
  onSelectDate: (d: Date) => void = () => {};

  build() {
    Row({ space: 8 }) {
      ForEach(this.weekOverview, (day: DayOverview) => {
        Column() {
          Text(day.date.getDate().toString())
            .fontWeight(day.date.toDateString() === this.selectedDate.toDateString() ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(day.date.toDateString() === this.selectedDate.toDateString() ? Color.Blue : Color.Black)
          Circle()
            .width(6).height(6)
            .fill(day.completedCount > 0 ? Color.Green : Color.Transparent)
        }
        .onClick(() => this.onSelectDate(day.date))
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      })
    }
    .padding(8)
    .backgroundColor('#FAFAFA')
  }
}

@Component
struct PlaceholderHabitRow {
  @ObjectLink data: HabitWithDailyStatus; // 需要 Class 才能 ObjectLink，这里 interface 暂时传值或者改为 Prop
  // 为简单起见，这里用 Prop 或直接传参
  @Prop isSelected: boolean;
  @Prop canToggle: boolean;
  @Prop remainingText: string;
  onToggle: () => void = () => {};
  onLongPress: () => void = () => {};

  build() {
    Row() {
      if (this.isSelected) {
        Checkbox({ name: 'select', group: 'sel' }).select(true).margin({ right: 8 })
      }
      Column() {
        Text(this.data.habit.name).fontSize(16).fontWeight(FontWeight.Medium)
        Text(this.remainingText).fontSize(12).fontColor(Color.Gray)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(this.data.isCompleted ? "已完成" : "打卡")
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(30)
        .backgroundColor(this.data.isCompleted ? Color.Green : Color.Blue)
        .opacity(this.canToggle ? 1 : 0.5)
        .enabled(this.canToggle)
        .onClick(() => this.onToggle())
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
  }
}