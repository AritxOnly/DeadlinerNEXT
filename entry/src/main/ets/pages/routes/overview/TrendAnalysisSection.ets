import { hashColor } from "../../../utils/OverviewUtils";

@Component
export struct TrendAnalysisSection {
  @Link completionTimeStats: Array<[string, number]>; // [BucketName, Count]

  build() {
    Column() {
      Text("任务完成时间分布")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 20 })

      if (this.completionTimeStats.length === 0) {
        Column() {
          Text("暂无已完成任务数据").fontColor(Color.Gray)
        }.height(200).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 16 }) {
          ForEach(this.completionTimeStats, (item: [string, number]) => {
            ListItem() {
              Column() {
                Row() {
                  Text(item[0]).fontSize(14)
                  Blank()
                  Text(`${item[1]} 项`).fontSize(14).fontWeight(FontWeight.Bold)
                }.width('100%').margin({ bottom: 8 })

                // 简单的进度条可视化
                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(12)
                    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                    .borderRadius(6)

                  // 计算最大值来做比例 (简单起见，假设最大值为当前列表中的最大值)
                  Row()
                    .width(`${(item[1] / Math.max(...this.completionTimeStats.map(i => i[1]))) * 100}%`)
                    .height(12)
                    .backgroundColor(hashColor('完成')) // 使用绿色
                    .borderRadius(6)
                }
              }
              .padding(12)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .borderRadius(12)
            }
          })
        }
      }
    }
    .padding(16)
  }
}