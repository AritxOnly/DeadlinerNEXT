import { AITextInput } from '../../../../components/AITextInput';
import { LoadingMask } from '../../../../components/LoadingMask';
import { DateTimePicker } from '../../../../components/DateTimePicker';
import { TimeInputButton } from '../../../../components/TimeInputButton';

const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct TaskFormView {
  // —— 双向绑定的表单数据 ——
  @Link name: string;
  @Link note: string;
  @Link startTime: Date;
  @Link endTime: Date;

  // —— AI 相关配置 ——
  @Prop showAIInput: boolean = true;
  @Link aiInputText: string;
  @Link isAILoading: boolean;

  onAITriggered: () => Promise<void> = async () => {};

  @State inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color');

  private formatTime(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private showTimePicker(isStart: boolean) {
    if (this.isAILoading) return;

    DateTimePicker.show(this.getUIContext(), {
      selected: isStart ? this.startTime : this.endTime,
      onAccept: (newDate: Date) => {
        if (isStart) {
          this.startTime = newDate;
        } else {
          this.endTime = newDate;
        }
      }
    });
  }

  build() {
    Stack() {
      if (this.isAILoading) {
        LoadingMask()
          .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }

      Column({ space: 16 }) {
        if (this.showAIInput) {
          AITextInput({
            text: $aiInputText,
            placeholder: "询问 AI 以快速添加任务...",
            onAITriggered: this.onAITriggered
          })
        }

        // 任务名称
        TextInput({ placeholder: '任务名称', text: this.name })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.name = val;
          })

        // 时间选择
        TimeInputButton({
          title: '开始时间',
          content: this.formatTime(this.startTime),
          onClickButton: (): void => this.showTimePicker(true)
        })

        TimeInputButton({
          title: '结束时间',
          content: this.formatTime(this.endTime),
          onClickButton: (): void => this.showTimePicker(false)
        })

        // 备注
        TextArea({ placeholder: '备注 (可选)', text: this.note })
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
    }
  }
}