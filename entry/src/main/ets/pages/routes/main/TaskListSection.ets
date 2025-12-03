import { DDLStatus } from "../../../model/DDLStatus";
import { DDLItemCardSwipeable } from "../../components/TaskItemCard";
import { LengthMetrics } from "@kit.ArkUI";

interface TaskUIModel {
  title: string;
  remainingTimeAlt: string;
  note: string;
  progress: number;
  isStarred: boolean;
  status: DDLStatus;
}

@Component
export struct TaskListSection {
  @State taskList: Array<TaskUIModel> = [
    { title: "完成项目报告", remainingTimeAlt: "剩余时间：3小时", note: "加班完成报告", progress: 0.30, isStarred: true, status: DDLStatus.UNDERGO },
    { title: "准备会议资料", remainingTimeAlt: "剩余时间：5小时", note: "准备客户报告材料", progress: 0.50, isStarred: false, status: DDLStatus.NEAR },
    { title: "准备会议资料", remainingTimeAlt: "剩余时间：5小时", note: "准备客户报告材料", progress: 0.50, isStarred: false, status: DDLStatus.PASSED },
    { title: "修复 Bug", remainingTimeAlt: "剩余时间：1小时", note: "修复系统中的严重 Bug", progress: 0.60, isStarred: true, status: DDLStatus.COMPLETED },
  ];

  @State bgBottomColor: ResourceColor = $r('app.color.background_primary')
  @State bgTopColor: ResourceColor = $r('app.color.background_primary')

  onWillApplyTheme(theme: Theme): void {
    this.bgBottomColor = theme.colors.backgroundEmphasize
    this.bgTopColor = theme.colors.backgroundPrimary
  }

  build() {
    List({
      space: 8
    }) {
      ForEach(this.taskList, (item: TaskUIModel, index: number) => {
        DDLItemCardSwipeable({
          title: item.title,
          remainingTimeAlt: item.remainingTimeAlt,
          note: item.note,
          progress: item.progress,
          isStarred: item.isStarred,
          status: item.status
        })
      })
    }
    .padding({
      start: LengthMetrics.vp(12),
      end: LengthMetrics.vp(12)
    })
    .width("100%")
    .height("100%")
  }
}