import { SettingsDivider, SettingsItem, SettingsSection } from '../components/SettingsComponents';
import { WebParams } from '../common/WebBrowserPage'; // 调整引用路径
import { common, Want } from '@kit.AbilityKit';

@Component
export struct SupportPanelView {
  @Consume('appPathStack') appPathStack: NavPathStack;
  // 传入关闭回调，以便点击某个选项后自动收起
  public closeAction?: () => void;

  private context = getContext(this) as common.UIAbilityContext;

  private openWeb(title: string, url: string) {
    let want: Want = {
      action: 'ohos.want.action.viewData', // 意图：查看数据
      entities: ['entity.system.browsable'], // 实体：可浏览的（通常指浏览器）
      uri: url
    };

    this.context.startAbility(want).catch((err: object) => {
      console.error("Open System Browser failed", JSON.stringify(err));
    });
  }

  // 跳转应用市场评分
  private openAppStore() {
    let want: Want = {
      action: 'ohos.want.action.appdetail',
      uri: 'store://appgallery.huawei.com/app/detail?id=com.aritxonly.deadliner' // ⚠️请确认你的包名
    };
    this.context.startAbility(want).catch((err: object) => {
      console.error("Open AppGallery failed", JSON.stringify(err));
    });
    this.closeAction?.();
  }

  build() {
    Column() {

      Column({ space: 16 }) {
        // --- 核心共建区域 (GitHub) ---
        SettingsSection({ title: '开源共建' }) {
          SettingsItem({
            title: "源代码",
            subtitle: "AritxOnly/DeadlinerNEXT",
            icon: $r('sys.symbol.code'), // 代码图标
            onItemClick: () => {
              this.openWeb('GitHub Repository', 'https://github.com/AritxOnly/DeadlinerNEXT');
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "提交 Issue",
            subtitle: "反馈 Bug 或提出新功能建议",
            icon: $r('sys.symbol.exclamationmark_circle'), // 叹号图标
            onItemClick: () => {
              this.openWeb('Issues', 'https://github.com/AritxOnly/DeadlinerNEXT/issues');
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "Pull Request",
            subtitle: "贡献代码，参与开发",
            icon: $r('sys.symbol.link'), // 分支图标
            onItemClick: () => {
              this.openWeb('Pull Requests', 'https://github.com/AritxOnly/DeadlinerNEXT/pulls');
            }
          })
        }

        // --- 情感与支持区域 ---
        SettingsSection({ title: '支持作者' }) {
          SettingsItem({
            title: "去应用市场评分",
            subtitle: "五星好评是最大的鼓励",
            icon: $r('sys.symbol.star'),
            onItemClick: () => {
              this.openAppStore();
            }
          })

          SettingsDivider()

          SettingsItem({
            title: "请我喝杯咖啡",
            subtitle: "通过捐赠支持后续开发",
            icon: $r('sys.symbol.heart'),
            onItemClick: () => {
              this.openWeb('捐赠支持', 'https://aritxonly.top/donate_deadliner');
            }
          })
        }

        Blank().height(30)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
  }
}