import { DDLItem } from "../../../model/DDLModels";
import { hashColor } from "../../../utils/OverviewUtils";

@Component
export struct DashboardSection {
  @Prop overdueItems: DDLItem[];

  build() {
    Column() {
      Text("需要关注的任务")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 10 })

      if (this.overdueItems.length === 0) {
        Column() {
          Text("太棒了，没有逾期任务！").fontColor(Color.Gray).margin({top: 50})
        }.width('100%').alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.overdueItems, (item: DDLItem) => {
            ListItem() {
              Row() {
                // 红色竖线指示条
                Column().width(4).height(40).backgroundColor(hashColor('逾期')).borderRadius(2).margin({ right: 12 })

                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`截止: ${item.endTime}`)
                    .fontSize(12)
                    .fontColor(Color.Gray)
                    .margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                Text("已逾期")
                  .fontSize(12)
                  .fontColor(hashColor('逾期'))
                  .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                  .backgroundColor('#FFEEBZ') // 浅红背景 (需适配)
                  .borderRadius(4)
              }
              .padding(12)
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .borderRadius(12)
            }
          })
        }
        .layoutWeight(1)
      }
    }
    .padding(16)
    .height('100%')
  }
}