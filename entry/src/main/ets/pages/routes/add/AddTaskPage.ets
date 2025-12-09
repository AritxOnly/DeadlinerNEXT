import { promptAction } from '@kit.ArkUI';
import { TaskRepository } from '../../../common/repository/TaskRepository';
import { DeadlineType } from '../../../model/DDLModels';
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
    DatePickerDialog.show({
      start: new Date("2000-1-1"),
      end: new Date("2100-12-31"),
      selected: isStart ? this.startTime : this.endTime,
      onAccept: (value: DatePickerResult) => {
        const selectedDate = new Date(value.year!, value.month!, value.day!);
        TimePickerDialog.show({
          selected: isStart ? this.startTime : this.endTime,
          useMilitaryTime: true,
          onAccept: (timeValue: TimePickerResult) => {
            selectedDate.setHours(timeValue.hour, timeValue.minute);
            if (isStart) {
              this.startTime = selectedDate;
            } else {
              this.endTime = selectedDate;
            }
          }
        })
      }
    })
  }

  private parseDateString(dateStr: string): Date | null {
    if (!dateStr) return null;
    try {
      // 兼容 "2023-12-01 12:00" 这种格式
      // 替换空格为 T，并补全秒，变成标准 ISO 格式尝试解析
      const isoStr = dateStr.replace(' ', 'T') + ':00';
      const date = new Date(isoStr);
      if (isNaN(date.getTime())) {
        // 如果失败，尝试手动解析
        const parts = dateStr.split(/[- :]/);
        if (parts.length >= 5) {
          return new Date(
            parseInt(parts[0]),
            parseInt(parts[1]) - 1, // 月份从0开始
            parseInt(parts[2]),
            parseInt(parts[3]),
            parseInt(parts[4])
          );
        }
        return null;
      }
      return date;
    } catch (e) {
      return null;
    }
  }

  private async saveTask() {
    if (!this.name.trim()) {
      promptAction.showToast({ message: '请输入任务名称' });
      return;
    }

    try {
      const toLocalISO = (d: Date) => {
        const offset = d.getTimezoneOffset() * 60000;
        const local = new Date(d.getTime() - offset);
        return local.toISOString().slice(0, 19);
      };

      await TaskRepository.getInstance().insertDDL({
        name: this.name,
        startTime: toLocalISO(this.startTime),
        endTime: toLocalISO(this.endTime),
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

  @State inputBgColor: ResourceColor = $r('sys.color.background_tertiary')

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
          const parsedDate = this.parseDateString(param.dueTime);
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
  }
}