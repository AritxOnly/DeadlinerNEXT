export class WidgetData {
  /** 任务列表 (最多传3-4个，传太多会超卡片内存限制) */
  tasks: Array<WidgetTaskItem> = [];

  /** 更新时间 (用于调试或显示) */
  updateTime: string = '';

  /** 总未完成数 (用于标题栏显示 "5个待办") */
  totalCount: number = 0;
}

export class WidgetTaskItem {
  title: string = '';

  /** 显示的时间文本，如 "2小时后", "已逾期" */
  timeDesc: string = '';

  /** 是否紧急 (用于显示红色高亮) */
  isUrgent: boolean = false;
}