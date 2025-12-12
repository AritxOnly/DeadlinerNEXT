import { promptAction } from '@kit.ArkUI';
import { TaskRepository } from '../../common/repository/TaskRepository';
import { DDLItem } from '../../model/DDLModels';
import { ArchivedDDLItemCard } from './TaskItemCard';

@Component
export struct ArchivePanelView {
  @State archivedItems: DDLItem[] = [];
  @State isLoading: boolean = true;

  // 获取仓库实例
  private repo = TaskRepository.getInstance();

  aboutToAppear() {
    this.refreshData();
  }

  async refreshData() {
    this.isLoading = true;
    try {
      // 1. 获取所有 DDL
      const allItems = await this.repo.getAllDDLs();

      // 2. 筛选 isArchived = true (或者 1，取决于你的 Model 定义是 boolean 还是 number)
      // 并按完成时间倒序排列（最近完成的在上面）
      this.archivedItems = allItems
        .filter(item => item.isArchived)
        .sort((a, b) => {
          const timeA = a.completeTime ? new Date(a.completeTime).getTime() : 0;
          const timeB = b.completeTime ? new Date(b.completeTime).getTime() : 0;
          return timeB - timeA;
        });

    } catch (e) {
      console.error(`[ArchivePanel] Load failed: ${e}`);
    } finally {
      this.isLoading = false;
    }
  }

  async handleDelete(item: DDLItem) {
    // 弹窗确认
    AlertDialog.show({
      title: '永久删除',
      message: `确定要永久删除任务“${item.name}”吗？此操作不可恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          try {
            await this.repo.deleteDDL(item.id);
            // 删除成功后，从当前列表中移除，不必重新读库，提升体验
            const index = this.archivedItems.indexOf(item);
            if (index !== -1) {
              this.archivedItems.splice(index, 1);
            }
            promptAction.showToast({ message: '已删除' });
          } catch (e) {
            console.error(`Delete failed: ${e}`);
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    });
  }

  // 简单的日期格式化 helper
  private formatDate(dateStr: string): string {
    if (!dateStr) return '未知时间';
    try {
      const date = new Date(dateStr);
      // 返回格式：MM-dd HH:mm
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      const hour = date.getHours().toString().padStart(2, '0');
      const minute = date.getMinutes().toString().padStart(2, '0');
      return `${month}-${day} ${hour}:${minute}`;
    } catch (e) {
      return dateStr;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        // 加载中状态
        Column() {
          LoadingProgress().width(48).height(48)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.archivedItems.length === 0) {
        // 空状态
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.archivebox'))
            .fontSize(64)
            .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])

          Text("没有归档的任务")
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        // 稍微往上偏移一点，视觉居中更好看
        .offset({ y: -48 })
      } else {
        // 列表展示
        List({ space: 12 }) {
          ForEach(this.archivedItems, (item: DDLItem) => {
            ListItem() {
              ArchivedDDLItemCard({
                title: item.name,
                startTime: this.formatDate(item.startTime),
                completeTime: this.formatDate(item.completeTime),
                note: item.note,
                onDelete: () => {
                  this.handleDelete(item);
                }
              })
            }
          }, (item: DDLItem) => item.id.toString())
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
  }
}