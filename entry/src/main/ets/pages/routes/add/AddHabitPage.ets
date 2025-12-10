import { promptAction } from '@kit.ArkUI';
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { DatabaseHelper } from '../../../common/data/DatabaseHelper';
import { DeadlineType, HabitGoalType, HabitPeriod, HabitStatus } from '../../../model/DDLModels';
import { TimeInputButton } from '../../components/TimeInputButton';

// 统一的样式常量
const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Builder
export function AddHabitBuilder(name: string, param: Object) {
  AddHabitPage()
}

@Component
export struct AddHabitPage {
  pageStack: NavPathStack = new NavPathStack();

  // 菜单：保存按钮
  saveMenuItem: NavigationMenuItem = {
    value: "Save",
    icon: 'resources/base/media/checkmark.svg',
    action: async () => {
      await this.saveHabit();
    }
  }

  // —— 表单状态 ——
  @State name: string = '';
  @State note: string = '';
  @State selectedPeriod: HabitPeriod = HabitPeriod.DAILY;
  @State timesPerPeriod: string = '1';
  @State goalType: HabitGoalType = HabitGoalType.PER_PERIOD;
  @State totalTarget: string = '';

  // 颜色资源
  @State inputBgColor: ResourceColor = $r('app.color.background_tertiary')
  @State brandColor: ResourceColor = $r('app.color.brand')
  @State onBrandColor: ResourceColor = Color.White
  @State surfaceVariantColor: ResourceColor = $r('app.color.background_tertiary')

  // —— 逻辑方法 ——
  private async saveHabit() {
    if (!this.name.trim()) {
      promptAction.showToast({ message: '请输入习惯名称' });
      return;
    }

    const times = parseInt(this.timesPerPeriod);
    if (isNaN(times) || times <= 0) {
      promptAction.showToast({ message: '请输入有效的单次目标' });
      return;
    }

    let total: number | null = null;
    if (this.goalType === HabitGoalType.TOTAL) {
      total = parseInt(this.totalTarget);
      if (isNaN(total) || total <= 0) {
        promptAction.showToast({ message: '请输入有效的总目标' });
        return;
      }
    }

    try {
      const now = new Date();
      const toLocalISO = (d: Date) => {
        const offset = d.getTimezoneOffset() * 60000;
        const local = new Date(d.getTime() - offset);
        return local.toISOString().slice(0, 19);
      };

      const dbHelper = DatabaseHelper.getInstance();
      const ddlId = await dbHelper.insertDDL({
        name: this.name,
        startTime: toLocalISO(now),
        endTime: toLocalISO(new Date(now.getFullYear() + 100, 0, 1)),
        isCompleted: false,
        completeTime: "",
        note: this.note,
        isArchived: false,
        isStared: false,
        type: DeadlineType.HABIT,
        calendarEventId: null
      });

      if (ddlId <= 0) throw new Error("Insert DDL failed");

      await HabitRepository.getInstance().createHabitForDdl(
        ddlId,
        this.name,
        this.selectedPeriod,
        times,
        this.goalType,
        total,
        this.note
      );

      promptAction.showToast({ message: '习惯创建成功' });
      getContext(this).eventHub.emit('sync_done');
      this.pageStack.pop();

    } catch (e) {
      console.error(`Add habit failed: ${e}`);
      promptAction.showToast({ message: '创建失败: ' + e.message });
    }
  }

  // —— UI 组件 Helper ——

  @Builder
  PeriodChip(period: HabitPeriod, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.selectedPeriod === period ? this.onBrandColor : Color.Gray)
      .backgroundColor(this.selectedPeriod === period ? this.brandColor : this.surfaceVariantColor)
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 }) // 内部 Padding 撑开高度
      .height(36) // 固定高度，保证整齐
      .onClick(() => {
        this.selectedPeriod = period;
      })
  }

  @Builder
  GoalTypeChip(type: HabitGoalType, label: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.goalType === type ? this.onBrandColor : Color.Gray)
      .backgroundColor(this.goalType === type ? this.brandColor : this.surfaceVariantColor)
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .height(36) // 固定高度，保证整齐
      .onClick(() => {
        this.goalType = type;
      })
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        // 1. 顶部说明
        Text("创建新习惯")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, top: 8 })

        Text("设定一个你想坚持的目标。")
          .fontSize(14)
          .fontColor(Color.Gray)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

        // 2. 习惯名称
        TextInput({ placeholder: '习惯名称', text: this.name })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.name = val;
          })

        // 3. 周期选择 (使用 Row 替代 Flex)
        Column({ space: 8 }) {
          Text("重复周期")
            .fontSize(14)
            .fontColor(Color.Gray)
            .padding({ left: 4 })

          // 使用 Row 包裹 Chip，如果担心换行问题，对于固定3个选项 Row 足够了
          Row({ space: 8 }) {
            this.PeriodChip(HabitPeriod.DAILY, "每日")
            this.PeriodChip(HabitPeriod.WEEKLY, "每周")
            this.PeriodChip(HabitPeriod.MONTHLY, "每月")
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 4. 目标设置 (Row + Column 布局)
        Row({ space: 12 }) {
          // 左侧：频率次数 (Column)
          Column({ space: 8 }) {
            Text("每次/频次")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })
            TextInput({ placeholder: '1', text: this.timesPerPeriod })
              .type(InputType.Number)
              .height(ITEM_HEIGHT)
              .fontSize(16)
              .backgroundColor(this.inputBgColor)
              .borderRadius(COMMON_RADIUS)
              .padding({ left: 16, right: 16 })
              .width('100%')
              .onChange((val) => {
                this.timesPerPeriod = val;
              })
          }
          .layoutWeight(1) // 占据剩余宽度

          // 右侧：目标类型 (Column)
          Column({ space: 8 }) {
            Text("目标类型")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })

            // 使用 Column 容器来包裹 Row，并手动居中
            Column() {
              Row({ space: 8 }) {
                this.GoalTypeChip(HabitGoalType.PER_PERIOD, "坚持")
                this.GoalTypeChip(HabitGoalType.TOTAL, "定量")
              }
            }
            .height(ITEM_HEIGHT) // 强制容器高度为 56vp (与左侧输入框一致)
            .justifyContent(FlexAlign.Center) // 垂直居中 Chip
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top) // 顶部对齐，确保标题在一条线上

        // 5. 总目标输入框
        if (this.goalType === HabitGoalType.TOTAL) {
          Column({ space: 8 }) {
            Text("总目标数量")
              .fontSize(14)
              .fontColor(Color.Gray)
              .padding({ left: 4 })

            TextInput({ placeholder: '例如：100 (页/次)', text: this.totalTarget })
              .type(InputType.Number)
              .height(ITEM_HEIGHT)
              .fontSize(16)
              .backgroundColor(this.inputBgColor)
              .borderRadius(COMMON_RADIUS)
              .padding({ left: 16, right: 16 })
              .width('100%')
              .onChange((val) => {
                this.totalTarget = val;
              })
          }
          .width('100%')
        }

        // 6. 备注
        TextArea({ placeholder: '备注 / 激励语 (可选)', text: this.note })
          .height(120)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.note = val;
          })
      }
      .width('100%')
      .height('100%')
      .padding(16)
    }
    .title('')
    .onReady((ctx) => {
      this.pageStack = ctx.pathStack;
    })
    .menus([
      this.saveMenuItem
    ])
  }
}