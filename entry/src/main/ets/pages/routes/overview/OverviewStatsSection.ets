import { DDLItem } from '../../../model/DDLModels';
import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';

// --- 颜色转换辅助函数 (保持不变) ---
function getHexColorSync(context: Context, resource: Resource): string {
  try {
    const colorVal = context.resourceManager.getColorSync(resource);
    let hex = (colorVal & 0xFFFFFF).toString(16).toUpperCase();
    while (hex.length < 6) {
      hex = "0" + hex;
    }
    return "#" + hex;
  } catch (e) {
    console.error(`Color conversion failed: ${e}`);
    return "#000000";
  }
}

interface ChartSeriesItem {
  name: string;
  value: number;
  color: string;
}

@Component
export struct OverviewStatsSection {
  // ... (Props 保持不变)
  @Prop todayCompleted: number;
  @Prop todayTodo: number;
  @Prop todayOverdue: number;
  @Link historyStats: Map<string, number>;
  @Link completionTimeStats: Array<[string, number]>;
  @ObjectLink overdueItems: DDLItem[];

  build() {
    Column({ space: 16 }) {
      ActiveStatsCard({
        completed: this.todayCompleted,
        todo: this.todayTodo,
        overdue: this.todayOverdue
      })

      CompletionTimeCard({ completionTimeStats: $completionTimeStats })

      HistoryStatsCard({ historyStats: $historyStats })

      Blank().height(40)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}

// ... (StatsCardContainer 保持不变)
@Component
struct StatsCardContainer {
  @BuilderParam content: () => void;
  build() {
    Column() { this.content() }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_card'))
    .clip(true)
  }
}

// ... (ActiveStatsCard 保持不变)
@Component
struct ActiveStatsCard {
  @Prop completed: number;
  @Prop todo: number;
  @Prop overdue: number;

  build() {
    StatsCardContainer() {
      Text("今日概况")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 20 })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        this.StatItem("今日完成", this.completed, $r('app.color.chart_green'))
        this.StatItem("待办任务", this.todo, $r('app.color.chart_orange'))
        this.StatItem("今日逾期", this.overdue, $r('app.color.chart_red'))
      }
    }
  }
  @Builder StatItem(label: string, value: number, color: ResourceColor) {
    Column() {
      Text(value.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor(color).margin({ bottom: 4 })
      Text(label).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }.alignItems(HorizontalAlign.Center)
  }
}

// =========================================
// 核心修改：CompletionTimeCard
// =========================================
@Component
struct CompletionTimeCard {
  @Link @Watch('updateChart') completionTimeStats: Array<[string, number]>;
  @State chartController: UChartsController = new UChartsController();

  updateChart() {
    if (!this.completionTimeStats || this.completionTimeStats.length === 0) return;

    const ctx = getContext(this);
    const blueColor = getHexColorSync(ctx, $r('app.color.chart_blue'));

    const categories: string[] = [];
    const dataValues: number[] = [];
    this.completionTimeStats.forEach(item => {
      categories.push(item[0]);
      dataValues.push(item[1]);
    });

    // 稍微加宽一点柱子，减少间距
    let barWidth = 30;

    const opts: ChartOptions = {
      type: "bar",
      categories: categories,
      series: [{
        name: "完成数",
        data: dataValues,
      }],
      color: [blueColor],

      // [关键修复 1] Padding 调整 [上, 右, 下, 左]
      // 左侧给 100 或更多，确保 "深夜 (00-06)" 能完全显示，不被截断
      padding: [10, 40, 10, 0],

      legend: { show: false },

      // [关键修复 2] 在 bar 模式下，xAxis 控制的是左侧的分类轴
      // 必须开启 (disabled: false)，否则文字不显示
      xAxis: {
        disabled: true,
        disableGrid: true,
        axisLine: false
      },

      // [关键修复 3] 在 bar 模式下，yAxis 控制的是底部的数值轴
      // 我们可以关掉它，让界面更干净
      yAxis: {
        disabled: false,
        disableGrid: true,
        padding: 2
      },

      extra: {
        bar: {
          type: "group",
          width: barWidth,
          barBorderCircle: true,

          seriesGap: 2,
          categoryGap: 2,
          // [渐变效果]
          // opacity: 颜色从纯色(左) 渐变到 透明(右)
          // 配合 linearOpacity 控制透明端的透明度
          linearType: 'opacity',
          linearOpacity: 0.5
        }
      }
    };

    this.chartController.updateData(opts);
  }

  build() {
    StatsCardContainer() {
      Text("完成时间分布")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 10 })

      if (this.completionTimeStats.length > 0) {
        Column() {
          UCharts({
            controller: this.chartController,
            onReady: () => { this.updateChart(); }
          })
        }
        .width('100%')
        .height(280)
      } else {
        Column() {
          Text("暂无已完成数据")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .height(100)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
    }
  }
}

@Component
struct HistoryStatsCard {
  @Link @Watch('updateChart') historyStats: Map<string, number>;
  @State chartController: UChartsController = new UChartsController();

  updateChart() {
    if (!this.historyStats || this.historyStats.size === 0) return;

    const ctx = getContext(this);

    // 1. 获取图表数据颜色 (App定义)
    const greenColor = getHexColorSync(ctx, $r('app.color.chart_green'));
    const orangeColor = getHexColorSync(ctx, $r('app.color.chart_orange'));
    const redColor = getHexColorSync(ctx, $r('app.color.chart_red'));

    // 2. [新增] 获取文字和背景颜色 (系统定义，适配深色模式)
    // 标题颜色 -> 次要文本色
    const titleColor = getHexColorSync(ctx, $r('sys.color.ohos_id_color_text_secondary'));
    // 数字颜色 -> 主要文本色
    const subtitleColor = getHexColorSync(ctx, $r('sys.color.ohos_id_color_text_primary'));
    // 背景颜色 -> 卡片背景色 (用于 Ring 的 border 和 center，实现镂空效果)
    const cardBgColor = getHexColorSync(ctx, $r('sys.color.ohos_id_color_card_bg'));

    const completed = this.historyStats.get("累计完成") || 0;
    const todo = this.historyStats.get("当前待办") || 0;
    const overdue = this.historyStats.get("累计逾期") || 0;
    const total = completed + todo + overdue;

    const seriesData: ChartSeriesItem[] = [];
    if (completed > 0) seriesData.push({ name: "完成", value: completed, color: greenColor });
    if (todo > 0) seriesData.push({ name: "待办", value: todo, color: orangeColor });
    if (overdue > 0) seriesData.push({ name: "逾期", value: overdue, color: redColor });

    if (seriesData.length === 0) return;

    const opts: ChartOptions = {
      type: "ring",
      series: [{ data: seriesData }],
      padding: [5, 5, 20, 5],
      legend: {
        show: true,
        position: "bottom",
        float: "center",
        padding: 5,
        itemGap: 10,
        lineHeight: 20,
        margin: 5,
        // 图例文字颜色也建议跟随次要文本
        fontColor: titleColor
      },
      title: {
        value: "总计",
        fontSize: 14,
        color: titleColor // [修改] 使用资源颜色
      },
      subtitle: {
        value: total.toString(),
        fontSize: 24,
        color: subtitleColor // [修改] 使用资源颜色
      },
      extra: {
        ring: {
          ringWidth: 36,
          activeOpacity: 0.5,
          activeRadius: 10,
          offsetAngle: 0,
          labelWidth: 15,
          border: true,
          borderWidth: 2,
          // [修改] 边框和中心圆颜色设为卡片背景色
          // 这样在深色模式下，"缝隙"和"中间的洞"也是深色的，不会显得突兀
          borderColor: cardBgColor,
          centerColor: cardBgColor
        }
      }
    };
    this.chartController.updateData(opts);
  }

  build() {
    StatsCardContainer() {
      Text("历史统计")
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 10 })

      if (this.historyStats.size > 0 && Array.from(this.historyStats.values()).some(v => v > 0)) {
        Column() {
          UCharts({
            controller: this.chartController,
            onReady: () => { this.updateChart(); }
          })
        }
        .width('100%')
        .height(260)
      } else {
        Column() {
          Text("暂无数据")
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .height(100)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
    }
  }
}