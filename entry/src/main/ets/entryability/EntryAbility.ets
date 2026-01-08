import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeControl, window } from '@kit.ArkUI';
import { gDeadlinerTheme } from '../AppTheme';
import { LocalValues } from '../common/local/LocalValues';
import { DatabaseHelper } from '../common/data/DatabaseHelper';
import { TaskRepository } from '../common/repository/TaskRepository';
import { WidgetUpdater } from '../utils/WidgetUpdater';
import { buffer } from '@kit.ArkTS';
import auth from '@hw-agconnect/auth'
import { ReminderDataManager } from '../utils/notification/ReminderDataManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

      await LocalValues.getInstance().init(this.context);
      await DatabaseHelper.getInstance().init(this.context);
      TaskRepository.getInstance().setContext(this.context)
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    let file = await this.context.resourceManager.getRawFileContent('agconnect-services.json');
    let json: string = buffer.from(file.buffer).toString();
    auth.init(this.context, json);

    console.info('[EntryAbility] Initializing ReminderDataManager...');
    await ReminderDataManager.getInstance().init(this.context);

    await TaskRepository.getInstance().initialReminderCheck();

    this.checkLoginStatus();

    this.handleWidgetRoute(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWidgetRoute(want)
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }

      ThemeControl.setDefaultTheme(gDeadlinerTheme)
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    WidgetUpdater.updateAllWidgets(this.context)
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    WidgetUpdater.updateAllWidgets(this.context)
  }

  private checkLoginStatus() {
    AppStorage.setOrCreate('isLoggedIn', false);

    auth.getCurrentUser()
      .then((user) => {
        if (user) {
          hilog.info(0x0000, 'EntryAbility', 'User already logged in: %{public}s | %{public}s', user.getUid(), user.getDisplayName());
          // 状态确认：已登录
          AppStorage.setOrCreate('isLoggedIn', true);
        } else {
          hilog.info(0x0000, 'EntryAbility', 'User not logged in');
          // 状态确认：未登录
          AppStorage.setOrCreate('isLoggedIn', false);
        }
      })
      .catch((err: BusinessError) => {
        hilog.error(0x0000, 'EntryAbility', 'Check user failed: %{public}s', err.message);
        AppStorage.setOrCreate('isLoggedIn', false);
      });
  }

  /**
   * 统一处理小组件跳转逻辑
   */
  private handleWidgetRoute(want: Want) {
    if (want.parameters && want.parameters['target'] === 'addTask') {
      // 设置全局状态 'QuickAddTaskTrigger' 为 true
      // UI 监听到这个变为 true 后，就会打开弹窗
      AppStorage.setOrCreate('QuickAddTaskTrigger', true);
    }
  }
}