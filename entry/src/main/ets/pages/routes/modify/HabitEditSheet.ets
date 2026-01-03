import { ChipGroup, ChipGroupItemOptions, ChipSize, promptAction } from '@kit.ArkUI';
import { Habit, HabitGoalType, HabitPeriod, HabitStatus } from '../../../model/DDLModels';

// 常量定义
const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct HabitEditSheet {
  @Link @Watch('onShowChange') isShow: boolean;

  @Prop editingHabit: Habit | undefined;

  onSave: (habit: Habit) => Promise<void> = async () => {};

  // —— 内部 UI 状态 ——
  @State private inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color');
  @State private editingHabitName: string = '';
  @State private editingPeriodIndex: number[] = [0];
  @State private editingGoalTypeIndex: number[] = [0];
  @State private editingTimesPerPeriod: string = '1';
  @State private editingTotalTarget: string = '';

  // 选项配置
  private periodOptions: ChipGroupItemOptions[] = [
    { label: { text: "每日" } },
    { label: { text: "每周" } },
    { label: { text: "每月" } }
  ];

  private goalTypeOptions: ChipGroupItemOptions[] = [
    { label: { text: "坚持" } },
    { label: { text: "定量" } }
  ];

  // 辅助映射数组 (保持与 Options 顺序一致)
  private periodMap = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY];
  private goalMap = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];

  // 初始化数据
  onShowChange() {
    if (this.isShow && this.editingHabit) {
      this.initData(this.editingHabit);
    }
  }

  // 手动调用也支持
  aboutToAppear() {
    if (this.isShow && this.editingHabit) {
      this.initData(this.editingHabit);
    }
  }

  private initData(habit: Habit) {
    this.editingHabitName = habit.name;

    // 周期：枚举 -> 索引
    const pIndex = this.periodMap.indexOf(habit.period);
    this.editingPeriodIndex = [pIndex !== -1 ? pIndex : 0];

    // 目标类型：枚举 -> 索引
    const gIndex = this.goalMap.indexOf(habit.goalType);
    this.editingGoalTypeIndex = [gIndex !== -1 ? gIndex : 0];

    // 数字转字符串
    this.editingTimesPerPeriod = habit.timesPerPeriod.toString();
    this.editingTotalTarget = habit.totalTarget ? habit.totalTarget.toString() : "";
  }

  // 获取枚举值的辅助函数
  private getGoalTypeFromIndex(index: number): HabitGoalType {
    return this.goalMap[index] || HabitGoalType.PER_PERIOD;
  }

  private getPeriodFromIndex(index: number): HabitPeriod {
    return this.periodMap[index] || HabitPeriod.DAILY;
  }

  // 保存逻辑
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
    const pIndex = this.editingPeriodIndex.length > 0 ? this.editingPeriodIndex[0] : 0;
    const gIndex = this.editingGoalTypeIndex.length > 0 ? this.editingGoalTypeIndex[0] : 0;

    const newPeriod = this.getPeriodFromIndex(pIndex);
    const newGoalType = this.getGoalTypeFromIndex(gIndex);

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
      if (!this.editingHabit) {
        promptAction.showToast({ message: '数据异常' });
        return;
      }

      // 4. 构建更新后的对象
      // 使用传入的 editingHabit 作为基准，确保 id, ddlId, createdAt 等保持不变
      const updatedHabit: Habit = {
        id: this.editingHabit.id,
        ddlId: this.editingHabit.ddlId,
        name: this.editingHabitName,
        description: this.editingHabit.description || "",
        color: this.editingHabit.color,
        iconKey: this.editingHabit.iconKey,
        period: newPeriod,
        timesPerPeriod: times,
        goalType: newGoalType,
        totalTarget: total,
        createdAt: this.editingHabit.createdAt,
        updatedAt: new Date().toISOString(), // 更新时间
        status: this.editingHabit.status,
        sortOrder: this.editingHabit.sortOrder,
        alarmTime: this.editingHabit.alarmTime
      };

      // 5. 调用父组件回调
      await this.onSave(updatedHabit);

      // 6. UI 反馈与关闭
      promptAction.showToast({ message: '修改成功' });
      this.isShow = false;

    } catch (e) {
      console.error(`Update habit failed: ${e}`);
      promptAction.showToast({ message: '修改失败' });
    }
  }

  build() {
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
              selectedBackgroundColor: $r('app.color.accent'),
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
                selectedBackgroundColor: $r('app.color.accent'),
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

        Button('保存')
          .onClick((event: ClickEvent) => {
            this.saveHabitEdit();
          })
          .width('100%')
          .backgroundColor($r('app.color.accent'))

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}