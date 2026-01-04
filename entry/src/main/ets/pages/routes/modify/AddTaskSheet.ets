import { promptAction } from '@kit.ArkUI';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DeadlineType } from '../../../model/DDLModels';
import { DateTimeUtils } from '../../../utils/DateTimeUtils';
import { DateTimePicker } from '../../components/DateTimePicker';
import { TimeInputButton } from '../../components/TimeInputButton';
import { HdsNavigation, HdsNavigationAttribute, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { AITextInput } from '../../components/AITextInput';
import { AIService } from '../../../ai/AIServcice';
import { i18n } from '@kit.LocalizationKit';
import { LoadingMask } from '../../components/LoadingMask';

// 统一的样式常量
const COMMON_RADIUS = 24; // 需求1：圆角 24
const ITEM_HEIGHT = 56; // 统一高度

export interface AddTaskParams {
  name: string;
  note?: string;
  dueTime?: string; // 格式 "yyyy-MM-dd HH:mm"
}

@Component
export struct AddTaskSheet {
  onDone: () => void = () => {}

  saveMenuItem: NavigationMenuItem = {
    value: "Save",
    icon: 'resources/base/media/checkmark.svg',
    action: async () => {
      await this.saveTask();
    }
  }

  @State name: string = '';
  @State note: string = '';
  @State startTime: Date = new Date();
  @State endTime: Date = new Date(new Date().getTime() + 60 * 60 * 1000);

  private formatTime(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  private showTimePicker(isStart: boolean) {
    if (this.isAILoading) return;

    DateTimePicker.show(this.getUIContext(), {
      // 传入当前时间
      selected: isStart ? this.startTime : this.endTime,
      // 接收回调
      onAccept: (newDate: Date) => {
        if (isStart) {
          this.startTime = newDate;
        } else {
          this.endTime = newDate;
        }
      }
    });
  }

  private async saveTask() {
    if (!this.name.trim()) {
      promptAction.showToast({ message: '请输入任务名称' });
      return;
    }

    try {
      await TaskRepository.getInstance().insertDDL({
        name: this.name,
        startTime: DateTimeUtils.toLocalISOString(this.startTime),
        endTime: DateTimeUtils.toLocalISOString(this.endTime),
        note: this.note,
        isCompleted: false,
        completeTime: "",
        isArchived: false,
        isStared: false,
        type: DeadlineType.TASK,
        calendarEventId: null
      });

      promptAction.showToast({ message: '创建成功' });
      getContext(this).eventHub.emit('sync_done');
      this.onDone();

    } catch (e) {
      console.error(`Add task failed: ${e}`);
      promptAction.showToast({ message: '创建失败' });
    }
  }

  @State aiInputText: string = ''
  @State isAILoading: boolean = false

  async onAITriggered() {
    if (!this.aiInputText || !this.aiInputText.trim()) {
      promptAction.showToast({ message: '请输入内容后再尝试' });
      return;
    }

    this.isAILoading = true;
    try {
      const service = AIService.getInstance();
      const sysLang = i18n.System.getSystemLanguage();
      const results = await service.extractTasks(this.aiInputText, sysLang);
      if (results && results.length !== 0) {
        const task = results[0];
        this.name = task.name;
        this.note = task.note;
        const endDate = DateTimeUtils.parseDateString(task.dueTime);
        if (endDate) {
          this.endTime = endDate;
        }
      }
    } catch (err) {
      promptAction.showToast({
        message: `抱歉，遇到了一些问题：${err.message || '网络连接失败'}`
      })
    } finally {
      this.isAILoading = false;
    }
  }

  @State inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color')

  build() {
    HdsNavigation() {
      Stack() {
        if (this.isAILoading) {
          LoadingMask()
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
        }

        Column({ space: 16 }) {
          Blank().height(40)

          AITextInput({
            text: $aiInputText,
            onAITriggered: (): Promise<void> => this.onAITriggered()
          })

          Text("填写以下信息以设定你的 Deadline。")
            .fontColor($r('app.color.font_secondary'))
            .fontSize(14)
            .width('100%')
            .padding({ left: 16, right: 16 })

          // 2. 任务名称 (标准 TextInput)
          TextInput({ placeholder: '任务名称', text: this.name })
            .height(ITEM_HEIGHT)
            .fontSize(16)
            .backgroundColor(this.inputBgColor) // 显式设置背景色，确保一致
            .borderRadius(COMMON_RADIUS)     // 圆角 24
            .padding({ left: 16, right: 16 })
            .width('100%')
            .onChange((val) => {
              this.name = val;
            })

          // 3. 时间选择 (使用自定义 Builder 模拟 TextInput 样式)
          TimeInputButton({
            title: '开始时间',
            content: this.formatTime(this.startTime),
            onClickButton: (): void => this.showTimePicker(true)
          })

          TimeInputButton({
            title: '结束',
            content: this.formatTime(this.endTime),
            onClickButton: (): void => this.showTimePicker(false)
          })

          // 4. 备注 (TextArea)
          TextArea({ placeholder: '备注 (可选)', text: this.note })
            .height(120)
            .fontSize(16)
            .backgroundColor(this.inputBgColor) // 显式设置背景色
            .borderRadius(COMMON_RADIUS)     // 圆角 24
            .padding({
              top: 12,
              bottom: 12,
              left: 16,
              right: 16
            })
            .width('100%')
            .onChange((val) => {
              this.note = val;
            })

        }
        .width('100%')
        .height('100%')
        .padding(16)
      }
    }
    .titleBar({
      content: {
        title: {
          mainTitle: "创建新任务",
        },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.checkmark'),
                action: this.saveMenuItem.action
              }
            }
          ]
        },
        subIcon: {
          content: {
            icon: $r('sys.symbol.xmark'),
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