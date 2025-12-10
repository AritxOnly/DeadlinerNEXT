import { ChartOptions, UCharts, UChartsController } from '@ibestservices/ucharts';
import { StatsCardContainer } from '../../components/OverviewComponents'
import { DailyStat, MonthlyStat, WeeklyStat } from '../../../utils/OverviewUtils'

function getHexColorSync(context: Context, resource: Resource): string {
  try {
    const colorVal = context.resourceManager.getColorSync(resource);
    let hex = (colorVal & 0xFFFFFF).toString(16).toUpperCase();
    while (hex.length < 6) hex = "0" + hex;
    return "#" + hex;
  } catch (e) {
    return "#000000";
  }
}

// --- 3. 主组件 ---
@Component
export struct TrendAnalysisSection {
  @Link dailyStats: DailyStat[];
  @Link monthlyStats: MonthlyStat[];
  @Link weeklyStats: WeeklyStat[];

  build() {
    Column({ space: 16 }) {
      // 1. 每日完成情况 (柱状图)
      DailyCompletedCard({ dailyStats: $dailyStats })

      // 2. 每月趋势 (折线图)
      MonthlyTrendCard({ monthlyStats: $monthlyStats })

      // 3. 过去几周 (柱状图)
      PrevWeeksCard({ weeklyStats: $weeklyStats })

      // 底部留白
      Blank().height(40)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }
}

// =======================================================
// 卡片 1: 每日完成情况 (DailyCompletedCard)
// 图表类型: Column (垂直柱状图)
// =======================================================
@Component
struct DailyCompletedCard {
  @Link @Watch('updateChart') dailyStats: DailyStat[];
  @State chartController: UChartsController = new UChartsController();

  updateChart() {
    if (!this.dailyStats || this.dailyStats.length === 0) return;
    const ctx = getContext(this);
    const greenColor = getHexColorSync(ctx, $r('app.color.chart_green'));
    const redColor = getHexColorSync(ctx, $r('app.color.chart_red'));

    const categories = this.dailyStats.map(it => it.dateStr);
    const completedData = this.dailyStats.map(it => it.completed);
    const overdueData = this.dailyStats.map(it => it.overdue);

    const opts: ChartOptions = {
      type: "column", // 垂直柱状图
      categories: categories,
      series: [
        { name: "完成", data: completedData, color: greenColor },
        { name: "逾期", data: overdueData, color: redColor }
      ],
      // Padding: [上, 右, 下, 左]
      padding: [15, 15, 5, 15],
      legend: { show: true, position: "bottom", float: "center" },
      xAxis: {
        disableGrid: true,
        axisLine: false
      },
      yAxis: {
        // 每日数据通常比较小，可以显示网格辅助线
        disableGrid: false,
        gridType: 'dash',
        data: [{ axisLine: false, tofix: 0 }]
      },
      extra: {
        column: {
          type: "group", // 分组显示 (并排)
          width: 20, // 柱子宽度
          activeBgColor: "#000000",
          activeBgOpacity: 0.08,
          // 渐变效果
          linearType: 'opacity',
          linearOpacity: 0.5
        }
      }
    };
    this.chartController.updateData(opts);
  }

  build() {
    StatsCardContainer() {
      Text("本周完成情况") // stringResource(R.string.weekly_completed)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })

      if (this.dailyStats.length > 0) {
        Column() {
          UCharts({
            controller: this.chartController,
            onReady: () => { this.updateChart(); }
          })
        }
        .width('100%')
        .height(220)
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}

// =======================================================
// 卡片 2: 每月趋势 (MonthlyTrendCard)
// 图表类型: Line (折线图)
// =======================================================
@Component
struct MonthlyTrendCard {
  @Link @Watch('updateChart') monthlyStats: MonthlyStat[];
  @State chartController: UChartsController = new UChartsController();

  updateChart() {
    if (!this.monthlyStats || this.monthlyStats.length === 0) return;
    const ctx = getContext(this);
    const blueColor = getHexColorSync(ctx, $r('app.color.chart_blue'));
    const greenColor = getHexColorSync(ctx, $r('app.color.chart_green'));
    const redColor = getHexColorSync(ctx, $r('app.color.chart_red'));

    const categories = this.monthlyStats.map(it => it.monthStr);
    const totalData = this.monthlyStats.map(it => it.total);
    const completedData = this.monthlyStats.map(it => it.completed);
    const overdueData = this.monthlyStats.map(it => it.overdue);

    const opts: ChartOptions = {
      type: "line",
      categories: categories,
      series: [
        { name: "总计", data: totalData, color: blueColor },
        { name: "完成", data: completedData, color: greenColor },
        { name: "逾期", data: overdueData, color: redColor }
      ],
      padding: [15, 15, 5, 15],
      legend: { show: true, position: "bottom", float: "center" },
      xAxis: { disableGrid: true, axisLine: false },
      yAxis: {
        disableGrid: false,
        gridType: 'dash',
        data: [{ axisLine: false, tofix: 0 }]
      },
      extra: {
        line: {
          type: "curve", // 曲线
          width: 2,
          activeType: "hollow"
        }
      }
    };
    this.chartController.updateData(opts);
  }

  build() {
    StatsCardContainer() {
      Text("每月趋势") // stringResource(R.string.monthly_trend)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })

      if (this.monthlyStats.length > 0) {
        Column() {
          UCharts({
            controller: this.chartController,
            onReady: () => { this.updateChart(); }
          })
        }
        .width('100%')
        .height(240) // 折线图通常可以稍高一点
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}

// =======================================================
// 卡片 3: 过去几周 (PrevWeeksCard)
// 图表类型: Column (垂直柱状图)
// =======================================================
@Component
struct PrevWeeksCard {
  @Link @Watch('updateChart') weeklyStats: WeeklyStat[];
  @State chartController: UChartsController = new UChartsController();

  updateChart() {
    if (!this.weeklyStats || this.weeklyStats.length === 0) return;
    const ctx = getContext(this);
    const secondaryColor = getHexColorSync(ctx, $r('app.color.chart_orange')); // 或者用其他辅色

    const categories = this.weeklyStats.map(it => it.weekLabel);
    const dataValues = this.weeklyStats.map(it => it.completed);

    const opts: ChartOptions = {
      type: "column",
      categories: categories,
      series: [
        { name: "完成", data: dataValues, color: secondaryColor }
      ],
      padding: [15, 15, 5, 15],
      legend: { show: false }, // 单一数据不需要图例
      xAxis: { disableGrid: true, axisLine: false },
      yAxis: {
        disableGrid: false,
        gridType: 'dash',
        data: [{ axisLine: false, tofix: 0 }]
      },
      extra: {
        column: {
          type: "group",
          width: 30, // 柱子稍微宽一点
          linearType: 'opacity',
          linearOpacity: 0.5
        }
      }
    };
    this.chartController.updateData(opts);
  }

  build() {
    StatsCardContainer() {
      Text("近4周完成") // stringResource(R.string.prev4weeks)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 10 })

      if (this.weeklyStats.length > 0) {
        Column() {
          UCharts({
            controller: this.chartController,
            onReady: () => { this.updateChart(); }
          })
        }
        .width('100%')
        .height(200)
      } else {
        this.EmptyView()
      }
    }
  }

  @Builder EmptyView() {
    Text("暂无数据")
      .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
      .height(100)
      .width('100%')
      .textAlign(TextAlign.Center)
  }
}