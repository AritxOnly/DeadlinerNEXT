import { promptAction } from '@kit.ArkUI';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DeadlineType } from '../../../model/DDLModels';
import { DateTimeUtils } from '../../../utils/DateTimeUtils';
import { DateTimePicker } from '../../components/DateTimePicker';
import { TimeInputButton } from '../../components/TimeInputButton';

// 统一的样式常量
const COMMON_RADIUS = 24; // 需求1：圆角 24
const ITEM_HEIGHT = 56; // 统一高度

export interface AddTaskParams {
  name: string;
  note?: string;
  dueTime?: string; // 格式 "yyyy-MM-dd HH:mm"
}

@Builder
export function AddTaskBuilder(name: string, param: Object) {
  AddTaskPage()
}

@Component
export struct AddTaskPage {
  pageStack: NavPathStack = new NavPathStack();

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
      this.pageStack.pop();

    } catch (e) {
      console.error(`Add task failed: ${e}`);
      promptAction.showToast({ message: '创建失败' });
    }
  }

  @State inputBgColor: ResourceColor = $r('app.color.background_secondary')

  build() {
    NavDestination() {
      Column({ space: 16 }) { // 控件之间的间距

        // 1. 顶部说明文字
        Text("创建新任务")
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 4, top: 8 })

        Text("填写以下信息以设定你的 Deadline。")
          .fontSize(14)
          .fontColor(Color.Gray)
          .width('100%')
          .padding({ left: 4, bottom: 8 })

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

      const param = ctx.pathInfo.param as AddTaskParams;
      if (param) {
        if (param.name) this.name = param.name;
        if (param.note) this.note = param.note;

        // 处理时间
        if (param.dueTime) {
          const parsedDate = DateTimeUtils.parseDateString(param.dueTime);
          if (parsedDate) {
            this.endTime = parsedDate;
            // 智能设定开始时间：如果截止时间很近，开始时间设为现在；否则设为截止前1小时
            // 这里简单处理：开始时间设为当前时间
            this.startTime = new Date();
          }
        }
      }
    })
    .menus([
      this.saveMenuItem
    ])
    .backgroundColor($r('app.color.background_primary'))
  }
}