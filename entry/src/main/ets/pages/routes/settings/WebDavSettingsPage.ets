import { SettingsConstants } from "../../../common/local/SettingsConstants";
import { LocalValues } from "../../../common/local/LocalValues";
import { promptAction } from '@kit.ArkUI'; // 用于显示 Toast
import { WebUtils } from '../../../common/network/WebUtils'; // 引用我们之前写的网络工具
import { DatabaseHelper } from '../../../common/data/DatabaseHelper'; // 引用数据库工具
import { SyncService } from "../../../common/sync/SyncService";

@Builder
export function SettingsWebDavBuilder(name: string, param: Object) {
  SettingsWebDavPage()
}

@Component
export struct SettingsWebDavPage {
  // Navigation 路由栈引用
  pageStack: NavPathStack = new NavPathStack();

  @StorageLink(SettingsConstants.KEY_CLOUD_SYNC_ENABLE) syncEnable: boolean = false;
  @StorageLink(SettingsConstants.KEY_WEBDAV_URL) webUrl: string = '';
  @StorageLink(SettingsConstants.KEY_WEBDAV_USERNAME) username: string = '';
  @StorageLink(SettingsConstants.KEY_WEBDAV_PASSWORD) password: string = '';

  @State isSyncing: boolean = false;

  @State buttonBg: ResourceColor = $r('sys.color.brand')

  onWillApplyTheme(theme: Theme): void {
    this.buttonBg = theme.colors.brand
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) { // 增加间距让布局更好看

        // 1. 同步开关
        Row() {
          Text("启用云同步").fontSize(16).fontWeight(FontWeight.Medium)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.syncEnable })
            .onChange((isOn) => {
              LocalValues.getInstance().setCloudSyncEnable(isOn);
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })

        // 2. WebDAV 地址
        TextInput({ text: this.webUrl, placeholder: 'WebDAV 地址 (例如 https://dav.jianguoyun.com/dav/)' })
          .type(InputType.URL)
          .onChange((value) => {
            this.webUrl = value;
          })
          .onSubmit(() => {
            // 回车保存
            LocalValues.getInstance().setWebDavUrl(this.webUrl);
          })

        // 3. 用户名
        TextInput({ text: this.username, placeholder: '用户名' })
          .onChange((value) => {
            this.username = value;
          })

        // 4. 密码
        TextInput({ text: this.password, placeholder: '密码 / 应用授权码' })
          .type(InputType.Password)
          .onChange((value) => {
            this.password = value;
          })

        Divider().color(Color.Transparent).height(20)

        Blank()

        // 5. 保存并测试按钮
        Button(this.isSyncing ? '正在同步...' : '保存并与云端同步', { type: ButtonType.Capsule })
          .width('90%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(this.buttonBg)
          .onClick(async () => {
            this.isSyncing = true;
            try {
              LocalValues.getInstance().setWebDavAuth(this.username, this.password);
              LocalValues.getInstance().setWebDavUrl(this.webUrl)

              // 1. 准备依赖
              const db = DatabaseHelper.getInstance();
              const web = new WebUtils(this.webUrl, this.username, this.password);

              // 2. 初始化同步服务
              const service = new SyncService(db, web);

              // 3. 执行同步
              promptAction.showToast({ message: '开始同步...' });
              const success = await service.syncOnce();

              if (success) {
                promptAction.showToast({ message: '同步成功！请返回首页查看数据。' });

                getContext(this).eventHub.emit('sync_done');
              } else {
                promptAction.showToast({ message: '同步失败，请检查日志。' });
              }
            } catch (e) {
              console.error(`Sync Error: ${e}`);
              promptAction.showToast({ message: `发生错误: ${e.message}` });
            } finally {
              this.isSyncing = false;
            }
          })
      }
      .height('100%')
      .padding(16)
    }
    .title("WebDav设置")
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}