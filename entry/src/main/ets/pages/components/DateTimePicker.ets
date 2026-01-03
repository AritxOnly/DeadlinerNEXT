import { ComponentContent, promptAction } from '@kit.ArkUI';

// 1. 定义参数接口
class DateTimeDialogParams {
  selectedDate: Date = new Date();
  onAccept: (date: Date) => void = () => {};
  close: () => void = () => {};
}

// 2. 核心组件：处理状态联动
@Component
struct DateTimeContent {
  // 接收初始参数
  @Prop initialDate: Date = new Date();
  onAccept: (date: Date) => void = () => {};
  close: () => void = () => {};

  // 内部状态，用于驱动标题和选择器联动
  @State currentDate: Date = new Date();

  aboutToAppear() {
    // 初始化内部状态
    this.currentDate = new Date(this.initialDate);
  }

  // 辅助方法：获取格式化的日期标题
  private getTitle(date: Date): string {
    const weekDays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    // 格式：2026年1月3日 星期六
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${weekDays[date.getDay()]}`;
  }

  build() {
    Column() {
      // --- 标题栏 (修改点2：居中 + 动态日期) ---
      Row() {
        Text(this.getTitle(this.currentDate)) // 绑定 @State
          .fontSize(18) // 稍微调小一点点看起来更精致
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.Black)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center) // 居中对齐
      .padding({ top: 24, bottom: 16 })

      // --- 核心选择区 ---
      Row() {
        // 左侧：日期选择器
        DatePicker({
          start: new Date('2000-1-1'),
          end: new Date('2100-12-31'),
          selected: this.currentDate // 绑定状态
        })
          .onDateChange((value: Date) => {
            // 更新状态，触发标题重绘
            this.currentDate.setFullYear(value.getFullYear());
            this.currentDate.setMonth(value.getMonth());
            this.currentDate.setDate(value.getDate());
            // 重新赋值给自身以触发 @State 更新机制 (对象属性变更有时需要)
            this.currentDate = new Date(this.currentDate);
          })
          .layoutWeight(3)
          .height(220)
          // 🔥 修改点1：选中项颜色改为 Brand 颜色
          .selectedTextStyle({
            color: $r('app.color.brand'),
            font: { weight: FontWeight.Medium, size: 18 }
          })

        // 右侧：时间选择器
        TimePicker({
          selected: this.currentDate // 绑定状态
        })
          .useMilitaryTime(true)
          .onChange((value: TimePickerResult) => {
            this.currentDate.setHours(value.hour);
            this.currentDate.setMinutes(value.minute);
            this.currentDate = new Date(this.currentDate);
          })
          .layoutWeight(2)
          .height(220)
          // 🔥 修改点1：选中项颜色改为 Brand 颜色
          .selectedTextStyle({
            color: $r('app.color.brand'),
            font: { weight: FontWeight.Medium, size: 18 }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // --- 底部按钮栏 ---
      Row() {
        Button("取消")
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand')) // 按钮也保持 Brand 颜色
          .onClick(() => {
            this.close();
          })
          .layoutWeight(1)

        Divider().vertical(true).height(24).color(Color.Gray).opacity(0.3)

        Button("确定")
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand')) // 按钮也保持 Brand 颜色
          .onClick(() => {
            this.onAccept(this.currentDate);
            this.close();
          })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ bottom: 16, top: 16 })
    }
    .padding({ left: 8, right: 8 })
    .width('95%')
    .borderRadius(36)
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}

// 3. 全局 Builder 包装器 (仅负责实例化组件)
@Builder
function DateTimeBuilderWrapper(params: DateTimeDialogParams) {
  DateTimeContent({
    initialDate: params.selectedDate,
    onAccept: params.onAccept,
    close: params.close
  })
}

// 4. 静态工具类 (保持不变)
interface DateTimePickerOptions {
  selected?: Date;
  onAccept: (date: Date) => void;
}

export class DateTimePicker {
  static show(context: UIContext, options: DateTimePickerOptions) {
    const params = new DateTimeDialogParams();
    params.selectedDate = options.selected ? new Date(options.selected) : new Date();
    params.onAccept = options.onAccept;

    // 使用 Wrapper Builder
    const contentNode = new ComponentContent(context, wrapBuilder(DateTimeBuilderWrapper), params);

    params.close = () => {
      const prompt = context.getPromptAction();
      prompt.closeCustomDialog(contentNode);
    };

    const prompt = context.getPromptAction();
    prompt.openCustomDialog(contentNode, {
      alignment: DialogAlignment.Center,
      autoCancel: true,
      isModal: true,
      onWillDismiss: (dismissDialogAction: DismissDialogAction) => {
        if (dismissDialogAction.reason == DismissReason.TOUCH_OUTSIDE) {
          dismissDialogAction.dismiss()
        }
      }
    });
  }
}