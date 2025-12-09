import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { TaskRepository } from '../common/repository/TaskRepository';
import { common } from '@kit.AbilityKit';
import { WidgetData, WidgetTaskItem } from '../widget/model/WidgetData'; // 路径根据实际情况调整

export class WidgetUpdater {

  /**
   * 刷新所有已知的卡片
   * @param context 必须要传 Context 才能读取 Preferences
   */
  public static async updateAllWidgets(context: common.Context) {
    try {
      // 1. 获取 Form IDs
      const pref = await preferences.getPreferences(context, 'widget_store');
      const formIds = (await pref.get('formIds', [])) as Array<string>;

      if (formIds.length === 0) {
        console.warn('[WidgetUpdater] No widgets to update.');
        return;
      }

      // 2. 准备数据
      const repo = TaskRepository.getInstance();
      // 确保 Repo 初始化（如果是在 FormAbility 中调用，可能没 init）
      repo.setContext(context);

      const allTasks = await repo.getAllDDLs();
      const now = new Date().getTime();

      // 过滤：未完成、未归档、未删除、非习惯
      const validTasks = allTasks
        .filter(t => !t.isCompleted && !t.isArchived && !t.deleted && t.type !== 'habit')
        .sort((a, b) => new Date(a.endTime).getTime() - new Date(b.endTime).getTime());

      // 3. 构造 WidgetData
      const widgetData = new WidgetData();
      widgetData.totalCount = validTasks.length;
      widgetData.updateTime = new Date().toLocaleTimeString();

      // 取前 3 个展示
      widgetData.tasks = validTasks.slice(0, 3).map(item => {
        const end = new Date(item.endTime).getTime();
        const diffHours = (end - now) / (1000 * 60 * 60);

        let timeText = '';
        let isUrgent = false;

        if (diffHours < 0) {
          timeText = '已逾期';
          isUrgent = true;
        } else if (diffHours < 24) {
          timeText = Math.ceil(diffHours) + '小时后';
          isUrgent = diffHours < 6;
        } else {
          timeText = Math.ceil(diffHours / 24) + '天后';
        }

        // Fix: Explicitly instantiate the class to satisfy ArkTS strict checks
        const widgetItem = new WidgetTaskItem();
        widgetItem.title = item.name;
        widgetItem.timeDesc = timeText;
        widgetItem.isUrgent = isUrgent;
        return widgetItem;
      });

      // 4. 封装数据
      const bindingData = formBindingData.createFormBindingData({
        widgetData: widgetData // 对应 @LocalStorageProp('widgetData')
      });

      // 5. 循环推送更新
      for (const id of formIds) {
        // console.debug(`[WidgetUpdater] Updating form ${id}`);
        await formProvider.updateForm(id, bindingData);
      }
      console.info(`[WidgetUpdater] Updated ${formIds.length} widgets.`);

    } catch (e) {
      console.error(`[WidgetUpdater] Update failed: ${e}`);
    }
  }
}