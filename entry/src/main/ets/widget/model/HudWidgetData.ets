export class HudWidgetData {
  /** * 顶部日期文本
   * 格式示例："今日 · 周四 / 1日"
   * 建议在 Ability 中直接格式化好，UI 只负责傻瓜式渲染
   */
  dateStr: string = '加载中...';

  /** * 是否有紧急/临近任务
   * 用于控制 UI 是否显示红色高亮、沙漏图标等
   */
  hasUrgent: boolean = false;

  /** * 最紧急的那一条任务的标题
   * 如果 hasUrgent 为 false，这里可以放“暂无紧急事项”或者留空
   */
  urgentTaskName: string = '';

  /** 临近任务数量 (红色数字) */
  imminentCount: number = 0;

  /** 普通待办数量 */
  todoCount: number = 0;

  /** 总计数量 */
  totalCount: number = 0;

  /** 习惯数量 */
  habitCount: number = 0;

  /** * 系统建议的反色字体颜色
   * 虽然我们设计上倾向于用白色+阴影，但保留这个字段作为兜底
   */
  sysTextColor: string = '#FFFFFF';
}