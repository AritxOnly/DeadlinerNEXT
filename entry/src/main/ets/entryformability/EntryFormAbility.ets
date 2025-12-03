import { FormExtensionAbility, formInfo, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { WidgetUpdater } from '../utils/WidgetUpdater';
import { WidgetData } from '../widget/model/WidgetData'; // 引入数据模型

export default class EntryFormAbility extends FormExtensionAbility {

  // 1. 卡片添加
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters![formInfo.FormParam.IDENTITY_KEY] as string;
    console.info(`[EntryFormAbility] onAddForm: ${formId}`);

    // 保存 ID
    this.saveFormId(formId);

    // 异步触发一次真实数据更新
    // (因为这里必须同步返回，所以先返回空数据，稍后 WidgetUpdater 会把 DB 数据推上来)
    setTimeout(() => {
      WidgetUpdater.updateAllWidgets(this.context);
    }, 50);

    // 修复：必须返回 FormBindingData，而不是 FormState
    const initialData = new WidgetData();
    initialData.totalCount = 0;
    initialData.tasks = [];
    return formBindingData.createFormBindingData(initialData);
  }

  // 2. 卡片移除
  onRemoveForm(formId: string) {
    console.info(`[EntryFormAbility] onRemoveForm: ${formId}`);
    this.deleteFormId(formId);
  }

  // 3. 卡片刷新事件
  onUpdateForm(formId: string) {
    console.info(`[EntryFormAbility] onUpdateForm: ${formId}`);
    WidgetUpdater.updateAllWidgets(this.context);
  }

  // === Preferences 辅助方法 ===
  private async saveFormId(formId: string) {
    try {
      const pref = await preferences.getPreferences(this.context, 'widget_store');
      const ids = (await pref.get('formIds', [])) as Array<string>;
      if (!ids.includes(formId)) {
        ids.push(formId);
        await pref.put('formIds', ids);
        await pref.flush();
      }
    } catch (e) {
      console.error(`[EntryFormAbility] Save ID failed: ${e}`);
    }
  }

  private async deleteFormId(formId: string) {
    try {
      const pref = await preferences.getPreferences(this.context, 'widget_store');
      let ids = (await pref.get('formIds', [])) as Array<string>;
      ids = ids.filter(id => id !== formId);
      await pref.put('formIds', ids);
      await pref.flush();
    } catch (e) {
      console.error(`[EntryFormAbility] Delete ID failed: ${e}`);
    }
  }
};