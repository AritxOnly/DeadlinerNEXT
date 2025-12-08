import { McPieChart, McBarChart, Options } from '@mcui/mccharts';
import { DDLItem } from '../../../model/DDLModels';
import { hashColor } from '../../../utils/OverviewUtils';

interface ChartItemStyle {
  color?: string;
  borderColor?: string;
  borderWidth?: number;
  barBorderRadius?: number;
}

interface ChartLabel {
  show?: boolean;
  formatter?: string;
  fontSize?: number;
  color?: string;
  position?: string;
}

interface ChartDataEntry {
  value?: number;
  name?: string;
  itemStyle?: ChartItemStyle;
  label?: ChartLabel;
}

// 颜色转换辅助函数：将 ResourceColor 或 string 转为 hex 字符串
// McCharts 需要 '#RRGGBB' 格式
function toHexColor(label: string): string {
  if (label.includes('完成')) return '#4CAF50';
  if (label.includes('逾期')) return '#F44336';
  if (label.includes('待办')) return '#FF9800';
  return '#2196F3';
}

@Component
export struct OverviewStatsSection {
  @Prop activeStats: Map<string, number>;
  @Prop historyStats: Map<string, number>;
  @Prop completionTimeStats: Array<[string, number]>;
  @ObjectLink overdueItems: DDLItem[];

  build() {
    Scroll() {
      Column({ space: 16 }) {
        // 1. 今日概况 (纯数字卡片)
        ActiveStatsCard({ activeStats: this.activeStats })

        // 2. 完成时间分布 (条形图)
        CompletionTimeCard({ completionTimeStats: this.completionTimeStats })

        // 3. 历史统计 (饼图)
        HistoryStatsCard({ historyStats: this.historyStats })

        // 底部留白
        Blank().height(20)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}

// --- 通用卡片容器 ---
@Component
struct StatsCardContainer {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_card'))
  }
}

// =========================================
// 1. ActiveStatsCard (保持不变，纯UI)
// =========================================
@Component
struct ActiveStatsCard {
  @Prop @Watch('onStatsUpdate') activeStats: Map<string, number>;

  // 使用 State 来驱动 UI，保证绝对刷新
  @State completed: number = 0;
  @State todo: number = 0;
  @State overdue: number = 0;

  aboutToAppear(): void {
    this.onStatsUpdate();
  }

  onStatsUpdate() {
    if (this.activeStats) {
      this.completed = this.activeStats.get("今日完成") || 0;
      this.todo = this.activeStats.get("待办任务") || 0;
      this.overdue = this.activeStats.get("今日逾期") || 0;
    }
  }

  build() {
    StatsCardContainer() {
      Text("今日概况")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 16 })

      Flex({ justifyContent: FlexAlign.SpaceEvenly }) {
        // 这里直接使用 State 变量
        this.StatItem("今日完成", this.completed)
        this.StatItem("待办任务", this.todo)
        this.StatItem("今日逾期", this.overdue)
      }
    }
  }

  @Builder
  StatItem(label: string, value: number) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .maxLines(1)

      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(toHexColor(label)) // 确保你有 toHexColor 函数
        .margin({ top: 8 })
    }
    .width(90)
    .alignItems(HorizontalAlign.Center)
  }
}

// =========================================
// 2. CompletionTimeCard (McBarChart)
// =========================================
@Component
struct CompletionTimeCard {
  @Prop @Watch('updateChart') completionTimeStats: Array<[string, number]>;

  // 使用 Options 对象配置
  @State barOptions: Options = new Options({});

  aboutToAppear(): void {
    this.updateChart();
  }

  updateChart() {
    // 1. 提取 X 轴标签和 Y 轴数据
    const xLabels: string[] = [];
    const seriesData: number[] = [];

    this.completionTimeStats.forEach((item) => {
      xLabels.push(item[0]); // 例如 "上午", "下午"
      seriesData.push(item[1]); // 数量
    });

    // 2. 配置 Options (参考 mcCharts 文档结构)
    this.barOptions = new Options({
      // X 轴配置
      xAxis: {
        data: xLabels,
        axisLabel: {
          color: '#888888',
          fontSize: 12
        }
      },
      // Y 轴配置
      yAxis: {
        name: '数量',
        axisLabel: {
          color: '#888888',
          fontSize: 12
        }
      },
      // 数据系列
      series: [
        {
          name: '任务数',
          type: 'bar', // 指定为柱状图
          data: seriesData,
          itemStyle: {
            color: '#2196F3', // 统一柱子颜色
            barBorderRadius: 4
          },
          label: {
            show: true, // 显示柱子顶部的数值
            position: 'top',
            color: '#333333'
          }
        }
      ],
      // 提示框
      tooltip: {
        show: true
      },
      // 网格线
      grid: {
        left: '5%',
        right: '5%',
        bottom: '5%',
        containLabel: true
      }
    });
  }

  build() {
    StatsCardContainer() {
      Text("完成时间分布")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 12 })

      if (this.completionTimeStats.length > 0) {
        Column() {
          // 渲染图表组件
          McBarChart({ options: this.barOptions })
        }
        .height(220) // 必须指定高度
        .width('100%')
      } else {
        Text("暂无已完成数据")
          .fontColor(Color.Gray)
          .margin({ top: 30, bottom: 30 })
          .alignSelf(ItemAlign.Center)
      }
    }
  }
}

// =========================================
// 3. HistoryStatsCard (McPieChart)
// =========================================
@Component
struct HistoryStatsCard {
  @Prop @Watch('updateChart') historyStats: Map<string, number>;

  @State pieOptions: Options = new Options({});

  aboutToAppear(): void {
    this.updateChart();
  }

  updateChart() {
    const dataItems: ChartDataEntry[] = [];
    const keys = ["累计完成", "当前待办", "累计逾期"];

    // 构建 ECharts 风格的 data 数组: [{value: 10, name: 'xx', itemStyle: {color: 'xx'}}]
    keys.forEach((key) => {
      const val = this.historyStats.get(key) || 0;
      if (val > 0) {
        dataItems.push({
          value: val,
          name: key,
          itemStyle: ({
            color: toHexColor(key) // 为每个切片指定颜色
          })
        });
      }
    });

    this.pieOptions = new Options({
      series: [
        {
          name: '历史统计',
          type: 'pie', // 指定为饼图
          radius: ['40%', '70%'], // 环形图效果: [内半径, 外半径]
          data: dataItems,
          label: {
            show: true,
            formatter: '{b}: {c}', // 显示 名字: 数值
            fontSize: 12,
            color: '#333333'
          },
          itemStyle: {
            borderColor: '#FFFFFF',
            borderWidth: 2
          }
        }
      ],
      tooltip: {
        show: true
      },
      legend: {
        show: true,
        bottom: '0%',
        itemWidth: 10,
        itemHeight: 10
      }
    });
  }

  build() {
    StatsCardContainer() {
      Text("任务状态统计")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      if (this.historyStats.size > 0) {
        Column() {
          // 渲染图表组件
          McPieChart({ options: this.pieOptions })
        }
        .height(250) // 必须指定高度
        .width('100%')
      } else {
        Text("暂无数据")
          .fontColor(Color.Gray)
          .margin({ top: 30, bottom: 30 })
          .alignSelf(ItemAlign.Center)
      }
    }
  }
}