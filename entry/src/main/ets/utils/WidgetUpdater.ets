import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { TaskRepository } from '../common/repository/TaskRepository';
import { common } from '@kit.AbilityKit';
import { WidgetData, WidgetTaskItem } from '../widget/model/WidgetData'; // 路径根据实际情况调整
import { LocalValues } from '../common/local/LocalValues';
import { fileIo as fs } from '@kit.CoreFileKit';

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

      const localValues = LocalValues.getInstance();
      await localValues.init(context);

      widgetData.isWhiteText = localValues.getWidgetIsWhiteText();

      const rawBgPath = localValues.getWidgetBackgroundImage();
      let file: fs.File | null = null;
      let formImageKey = 'bgImage';

      // 处理 file:// 前缀 (FormKit 加载沙箱图片必须要有 file://)
      if (rawBgPath && rawBgPath.length > 0) {
        const fsPath = rawBgPath.startsWith('file://') ? rawBgPath.substring(7) : rawBgPath;
        try {
          // 这里检查一下文件大小，确认压缩生效了
          const stat = fs.statSync(fsPath);
          console.info(`[WidgetUpdater] Sending BG image. Path: ${fsPath}, Size: ${stat.size} bytes`);

          if (stat.size > 1024 * 1024) {
            console.error('[WidgetUpdater] ⚠️ WARNING: Image size > 1MB, Widget might fail to render!');
          }

          file = fs.openSync(fsPath, fs.OpenMode.READ_ONLY);
          widgetData.backgroundImage = 'memory://' + formImageKey;
        } catch (err) {
          console.error(`[WidgetUpdater] Failed to open image: ${err}`);
          widgetData.backgroundImage = null;
        }
      }

      widgetData.tasks = validTasks.slice(0, 5).map(item => {
        const end = new Date(item.endTime).getTime();
        const diffHours = (end - now) / (1000 * 60 * 60);

        let timeText = '';
        let isUrgent = false;

        if (diffHours < 0) {
          timeText = '已逾期';
          isUrgent = true;
        } else if (diffHours < 24) {
          timeText = Math.floor(diffHours) + '小时后';
          isUrgent = diffHours < 6;
        } else {
          timeText = Math.floor(diffHours / 24) + '天后';
        }

        // Fix: Explicitly instantiate the class to satisfy ArkTS strict checks
        const widgetItem = new WidgetTaskItem();
        widgetItem.title = item.name;
        widgetItem.timeDesc = timeText;
        widgetItem.isUrgent = isUrgent;
        return widgetItem;
      });

      // 4. 封装数据
      let formData: Record<string, Object> = {
        'widgetData': widgetData
      };

      // 2. 如果有文件，将 formImages 加到这个普通对象里
      if (file) {
        let images: Record<string, number> = {};
        images[formImageKey] = file.fd;

        // 直接在这个普通对象上设置 formImages
        formData['formImages'] = images;
      }

      // 3. 使用构造好的对象创建 FormBindingData
      // createFormBindingData 接受 Object 类型，所以这里传入 formData 是合法的
      const bindingData = formBindingData.createFormBindingData(formData);

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