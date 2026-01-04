import { ChipSize, promptAction } from '@kit.ArkUI';
import { ChipGroup, ChipGroupItemOptions } from '@ohos.arkui.advanced.ChipGroup';
import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HabitRepository } from '../../../common/repository/HabitRepository';
import { DatabaseHelper } from '../../../common/data/DatabaseHelper';
import { DeadlineType, HabitGoalType, HabitPeriod } from '../../../model/DDLModels';
import { AITextInput } from '../../components/AITextInput';
import { AIService } from '../../../ai/AIServcice';
import { i18n } from '@kit.LocalizationKit';
import { LoadingMask } from '../../components/LoadingMask';

// 统一的样式常量
const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct AddHabitSheet {
  // 回调函数：完成或取消时调用
  onDone: () => void = () => {}

  // —— 状态定义 ——
  @State name: string = '';
  // 习惯周期状态
  @State selectedPeriodIndex: number[] = [0];
  // 目标类型状态
  @State selectedGoalTypeIndex: number[] = [0];

  @State timesPerPeriod: string = '1';
  @State totalTarget: string = '';

  @State aiInputText: string = ''

  @State inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color')

  // —— 选项定义 ——
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
  private getPeriodFromIndex(index: number): HabitPeriod {
    const map = [HabitPeriod.DAILY, HabitPeriod.WEEKLY, HabitPeriod.MONTHLY];
    return map[index] || HabitPeriod.DAILY;
  }

  private getGoalTypeFromIndex(index: number): HabitGoalType {
    const map = [HabitGoalType.PER_PERIOD, HabitGoalType.TOTAL];
    return map[index] || HabitGoalType.PER_PERIOD;
  }

  // —— 保存逻辑 ——
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

    // 防御性检查
    const pIndex = this.selectedPeriodIndex.length > 0 ? this.selectedPeriodIndex[0] : 0;
    const gIndex = this.selectedGoalTypeIndex.length > 0 ? this.selectedGoalTypeIndex[0] : 0;

    const currentGoalType = this.getGoalTypeFromIndex(gIndex);
    const currentPeriod = this.getPeriodFromIndex(pIndex);

    let total: number | null = null;
    if (currentGoalType === HabitGoalType.TOTAL) {
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
        note: "",
        isArchived: false,
        isStared: false,
        type: DeadlineType.HABIT,
        calendarEventId: null
      });

      if (ddlId <= 0) throw new Error("Insert DDL failed");

      await HabitRepository.getInstance().createHabitForDdl(
        ddlId,
        this.name,
        currentPeriod,
        times,
        currentGoalType,
        total,
        ""
      );

      promptAction.showToast({ message: '习惯创建成功' });

      // 通知全局刷新
      getContext(this).eventHub.emit('sync_done');

      // 调用关闭回调
      this.onDone();

    } catch (e) {
      console.error(`Add habit failed: ${e}`);
      promptAction.showToast({ message: '创建失败: ' + (e.message || e) });
    }
  }

  @State isAILoading: boolean = false;

  async onAITriggered() {
    if (!this.aiInputText || !this.aiInputText.trim()) {
      promptAction.showToast({ message: '请输入内容后再尝试' });
      return;
    }

    this.isAILoading = true;
    try {
      const service = AIService.getInstance();
      const sysLang = i18n.System.getSystemLanguage();

      const results = await service.extractHabits(this.aiInputText, sysLang);

      if (results && results.length !== 0) {
        const habit = results[0];

        // --- 数据回填逻辑 Start ---

        this.name = habit.name;

        // 对应 this.periodOptions 的顺序
        let pIndex = 0;
        if (habit.period === 'WEEKLY') pIndex = 1;
        else if (habit.period === 'MONTHLY') pIndex = 2;
        this.selectedPeriodIndex = [pIndex];

        this.timesPerPeriod = habit.timesPerPeriod.toString();

        // 对应 this.goalTypeOptions 的顺序
        let gIndex = 0;
        if (habit.goalType === 'TOTAL') {
          gIndex = 1;
          // 只有是定量目标时，才填充总目标数
          if (habit.totalTarget) {
            this.totalTarget = habit.totalTarget.toString();
          }
        }
        this.selectedGoalTypeIndex = [gIndex];

        // --- 数据回填逻辑 End ---
      }
    } catch (err) {
      promptAction.showToast({
        message: `抱歉，遇到了一些问题：${err.message || '网络连接失败'}`
      })
    } finally {
      this.isAILoading = false;
    }
  }

  build() {
    HdsNavigation() {
      Stack() {
        if (this.isAILoading) {
          LoadingMask()
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }

        Column({ space: 16 }) {
          // 顶部留白，配合 Modal 样式
          Blank().height(40)

          AITextInput({
            text: $aiInputText,
            placeholder: "询问 AI 以快速添加习惯...",
            onAITriggered: (): Promise<void> => this.onAITriggered()
          })

          // 副标题说明
          Text("设定一个你想坚持的目标。")
            .fontColor($r('app.color.font_secondary'))
            .fontSize(14)
            .width('100%')
            .padding({ left: 16, right: 16 })

          // 1. 习惯名称
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

          // 2. 周期选择 (使用 ChipGroup)
          Column({ space: 8 }) {
            Text("重复周期")
              .fontSize(14)
              .fontColor($r('app.color.font_secondary'))
              .padding({ left: 4 })

            ChipGroup({
              items: this.periodOptions,
              itemStyle: {
                size: ChipSize.NORMAL,
                backgroundColor: this.inputBgColor,
                fontColor: $r('app.color.font_secondary'),
                selectedBackgroundColor: $r('app.color.accent'),
                selectedFontColor: Color.White
              },
              selectedIndexes: this.selectedPeriodIndex,
              onChange: (indexes: number[]) => {
                this.selectedPeriodIndex = indexes;
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // 3. 目标设置
          Row({ space: 12 }) {
            // 左侧：频率次数
            Column({ space: 8 }) {
              Text("每次/频次")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
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
            .layoutWeight(1)

            // 右侧：目标类型 (使用 ChipGroup)
            Column({ space: 8 }) {
              Text("目标类型")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
                .padding({ left: 4 })

              ChipGroup({
                items: this.goalTypeOptions,
                itemStyle: {
                  size: ChipSize.NORMAL,
                  backgroundColor: this.inputBgColor,
                  fontColor: $r('app.color.font_secondary'),
                  selectedBackgroundColor: $r('app.color.accent'),
                  selectedFontColor: Color.White
                },
                selectedIndexes: this.selectedGoalTypeIndex,
                onChange: (indexes: number[]) => {
                  this.selectedGoalTypeIndex = indexes;
                }
              })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          // 4. 总目标输入框 (条件渲染)
          if (this.selectedGoalTypeIndex.length > 0 &&
            this.getGoalTypeFromIndex(this.selectedGoalTypeIndex[0]) === HabitGoalType.TOTAL) {
            Column({ space: 8 }) {
              Text("总目标数量")
                .fontSize(14)
                .fontColor($r('app.color.font_secondary'))
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

        }
        .width('100%')
        .height('100%')
        .padding(16)
      }
    }
    .titleBar({
      content: {
        title: {
          mainTitle: "创建新习惯",
        },
        // 右上角：保存 (Checkmark)
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.checkmark'), // 使用系统图标
                action: async () => {
                  await this.saveHabit();
                }
              }
            }
          ]
        },
        // 左上角：关闭 (Xmark)
        subIcon: {
          content: {
            icon: $r('sys.symbol.xmark'), // 使用系统图标
            action: this.onDone
          }
        }
      }
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
  }
}