export class DateTimeUtils {

  /**
   * 联动选择器：先选日期，再选时间
   * @param currentModel 当前绑定的时间对象 (Date)
   * @param onFinish 选择完成后的回调 (返回新的 Date)
   */
  static showDateTimePicker(currentModel: Date, onFinish: (date: Date) => void) {
    // 1. 显示日期选择器
    DatePickerDialog.show({
      start: new Date("2000-1-1"),
      end: new Date("2100-12-31"),
      selected: currentModel, // 默认选中当前时间
      onAccept: (dateValue: DatePickerResult) => {
        // 2. 用户选完日期后，暂存年月日
        // 注意：这里构造一个新的 Date 对象，此时时分秒默认是 00:00:00 或者当前时间，
        // 为了体验更好，我们建议把"旧时间"的时分秒先同步过来，
        // 这样打开时间选择器时，滚动条会停留在用户之前设定的时间，而不是跳到 00:00
        const tempDate = new Date(dateValue.year!, dateValue.month!, dateValue.day!);
        tempDate.setHours(currentModel.getHours());
        tempDate.setMinutes(currentModel.getMinutes());

        // 3. 立即显示时间选择器
        TimePickerDialog.show({
          // 🔥 核心修复点：这里必须传 tempDate (包含了新日期的对象)
          // 如果传 currentModel，标题栏就会显示旧日期
          selected: tempDate,
          useMilitaryTime: true,
          onAccept: (timeValue: TimePickerResult) => {
            // 4. 用户选完时间，合并到 tempDate
            tempDate.setHours(timeValue.hour, timeValue.minute);

            // 5. 通过回调返回最终结果
            onFinish(tempDate);
          },
          // 统一样式
          backgroundBlurStyle: BlurStyle.Regular,
          selectedTextStyle: { color: $r('app.color.brand') },
          acceptButtonStyle: { fontColor: $r('app.color.brand') },
          cancelButtonStyle: { fontColor: $r('app.color.brand') }
        })
      },
      // 统一样式
      backgroundBlurStyle: BlurStyle.Regular,
      selectedTextStyle: { color: $r('app.color.brand') },
      acceptButtonStyle: { fontColor: $r('app.color.brand') },
      cancelButtonStyle: { fontColor: $r('app.color.brand') }
    })
  }

  /**
   * 格式化为 UI 显示用的字符串
   * 格式: "yyyy-MM-dd HH:mm"
   */
  static formatForUI(date: Date): string {
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
  }

  /**
   * 转换为本地时间的 ISO 格式字符串 (用于存入 SQLite/RDB)
   * 解决默认 .toISOString() 是 UTC 时间的问题
   * 格式: "yyyy-MM-ddTHH:mm:ss"
   */
  static toLocalISOString(d: Date): string {
    // getTimezoneOffset 返回的是分钟，比如东八区是 -480
    const offset = d.getTimezoneOffset() * 60000;
    // 减去偏移量得到本地时间的时间戳
    const local = new Date(d.getTime() - offset);
    // 截取前19位，去掉 .xxxZ
    return local.toISOString().slice(0, 19);
  }

  /**
   * 解析各种格式的日期字符串
   * 兼容 "yyyy-MM-dd HH:mm" 和 "yyyy-MM-ddTHH:mm:ss"
   */
  static parseDateString(dateStr: string): Date | null {
    if (!dateStr) return null;
    try {
      // 兼容 "2023-12-01 12:00" -> "2023-12-01T12:00:00"
      let isoStr = dateStr;
      if (dateStr.includes(' ')) {
        isoStr = dateStr.replace(' ', 'T');
      }
      // 如果没有秒，补全 :00 (简单的容错)
      if (isoStr.split(':').length === 2) {
        isoStr += ':00';
      }

      const date = new Date(isoStr);
      if (isNaN(date.getTime())) {
        // 如果 Date 构造函数解析失败，尝试手动解析 split
        const parts = dateStr.split(/[- :T]/).filter(p => p !== '');
        if (parts.length >= 5) {
          return new Date(
            parseInt(parts[0]),
            parseInt(parts[1]) - 1, // 月份 0-11
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
}