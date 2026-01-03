import { promptAction } from '@kit.ArkUI';
import { DDLItem } from '../../../model/DDLModels';
import { DateTimeUtils } from '../../../utils/DateTimeUtils';
import { DateTimePicker } from '../../components/DateTimePicker';
import { TimeInputButton } from '../../components/TimeInputButton';

// 常量定义
const COMMON_RADIUS = 24;
const ITEM_HEIGHT = 56;

@Component
export struct TaskEditSheet {
  @Link @Watch('onShowChange') isShow: boolean;

  @Prop editingTask: DDLItem | null;

  onSave: (task: DDLItem) => Promise<void> = async () => {};

  @State private editingTitle: string = '';
  @State private editingNote: string = '';
  @State private editingStartTime: Date = new Date();
  @State private editingEndTime: Date = new Date();
  @State private inputBgColor: ResourceColor = $r('sys.color.search_container_focus_color');

  aboutToAppear(): void {
    this.loadData();
  }

  onShowChange() {
    this.loadData();
  }

  private loadData() {
    if (this.isShow && this.editingTask) {
      this.editingTitle = this.editingTask.name;
      this.editingNote = this.editingTask.note;
      // 转换时间字符串为 Date 对象
      this.editingStartTime = new Date(this.editingTask.startTime);
      this.editingEndTime = new Date(this.editingTask.endTime);
    } else {
      console.error('[Edit] Invalid data')
    }
  }

  // 你的原始业务逻辑：保存编辑
  private async saveEdit() {
    if (!this.editingTask) return;

    if (!this.editingTitle.trim()) {
      promptAction.showToast({ message: '任务名称不能为空' });
      return;
    }

    try {
      // 严格按照你的逻辑手动赋值，不使用 ...语法
      this.editingTask.name = this.editingTitle;
      this.editingTask.note = this.editingNote;
      this.editingTask.startTime = DateTimeUtils.toLocalISOString(this.editingStartTime);
      this.editingTask.endTime = DateTimeUtils.toLocalISOString(this.editingEndTime);

      // 调用父组件传入的保存方法 (替代原来的 this.repo.updateDDL 和 this.loadData)
      await this.onSave(this.editingTask);

      // 关闭弹窗
      this.isShow = false;
      promptAction.showToast({ message: '修改已保存' });

    } catch (e) {
      console.error('Save edit failed:', e);
      promptAction.showToast({ message: '保存失败' });
    }
  }

  // 你的原始业务逻辑：时间选择器
  private showTimePicker(isStart: boolean) {
    DateTimePicker.show(this.getUIContext(), {
      // 传入当前时间
      selected: isStart ? this.editingStartTime : this.editingEndTime,
      // 接收回调
      onAccept: (newDate: Date) => {
        if (isStart) {
          this.editingStartTime = newDate;
        } else {
          this.editingEndTime = newDate;
        }
      }
    });
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        // 任务名称
        TextInput({ placeholder: '任务名称', text: this.editingTitle })
          .height(ITEM_HEIGHT)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.editingTitle = val;
          })

        // 开始时间
        TimeInputButton({
          title: '开始时间',
          content: DateTimeUtils.formatForUI(this.editingStartTime),
          onClickButton: (): void => this.showTimePicker(true)
        })

        // 结束时间
        TimeInputButton({
          title: '结束',
          content: DateTimeUtils.formatForUI(this.editingEndTime),
          onClickButton: (): void => this.showTimePicker(false)
        })

        // 备注
        TextArea({ placeholder: '备注 (可选)', text: this.editingNote })
          .height(120)
          .fontSize(16)
          .backgroundColor(this.inputBgColor)
          .borderRadius(COMMON_RADIUS)
          .padding({ top: 12, bottom: 12, left: 16, right: 16 })
          .width('100%')
          .onChange((val) => {
            this.editingNote = val;
          })
          .enableKeyboardOnFocus(false) // 防止Sheet一打开键盘就弹起遮挡

        Button('保存')
          .onClick((event: ClickEvent) => {
            this.saveEdit();
          })
          .width('100%')
          .backgroundColor($r('app.color.accent'))

        Blank().height(60)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}