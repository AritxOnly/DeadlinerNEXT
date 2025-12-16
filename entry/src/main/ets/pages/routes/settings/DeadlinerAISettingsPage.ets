import { SettingsConstants } from "../../../common/local/SettingsConstants";
import { LocalValues } from "../../../common/local/LocalValues";
import { promptAction } from '@kit.ArkUI';
import { AIService } from "../../../ai/AIServcice"; // 引用我们写的 AI 服务
import { Theme } from '@kit.ArkUI';

@Builder
export function SettingsAIBuilder(name: string, param: Object) {
  DeadlinerAISettingsPage()
}

@Component
export struct DeadlinerAISettingsPage {
  // Navigation 路由栈引用
  pageStack: NavPathStack = new NavPathStack();

  // --- 绑定 AppStorage 数据 ---
  @StorageLink(SettingsConstants.KEY_AI_PROVIDER) provider: string = 'deepseek';
  @StorageLink(SettingsConstants.KEY_AI_MODEL) model: string = 'deepseek-chat';
  @StorageLink(SettingsConstants.KEY_AI_BASE_URL) baseUrl: string = 'https://api.deepseek.com';
  // API Key 属于敏感数据，通常 AppStorage 里存一份内存副本供 UI 显示掩码或编辑
  @StorageLink(SettingsConstants.KEY_AI_DEEPSEEK_API_KEY) apiKey: string = '';

  @State isTesting: boolean = false;
  @State buttonBg: ResourceColor = $r('sys.color.brand')

  onWillApplyTheme(theme: Theme): void {
    // 适配主题色
    this.buttonBg = theme.colors.brand
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) { // 增加一点间距

        // 1. 顶部提示信息
        Text("目前仅支持 DeepSeek 直连模式。请确保您的网络环境可以访问 DeepSeek API。")
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding({ left: 4, right: 4 })

        // 2. API Key 输入框 (核心)
        Column({ space: 8 }) {
          Text("API Key (sk-...)")
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .width('100%')

          TextInput({ text: this.apiKey, placeholder: '请输入 DeepSeek API Key' })
            .type(InputType.Password) // 密码模式，保护隐私
            .showPasswordIcon(true)   // 允许查看
            .onChange((value) => {
              this.apiKey = value;
            })
        }

        Divider().color(Color.Transparent).height(4)

        // 3. 高级设置区域 (模型与地址)
        Column({ space: 12 }) {
          Text("高级设置")
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')

          // 模型名称
          Row() {
            Text("模型名称").width(80).fontSize(16)
            TextInput({ text: this.model, placeholder: 'deepseek-chat' })
              .layoutWeight(1)
              .onChange((value) => {
                this.model = value;
              })
              .enabled(false)
          }

          // API 地址 (方便将来切自定义代理)
          Row() {
            Text("API 地址").width(80).fontSize(16)
            TextInput({ text: this.baseUrl, placeholder: 'https://api.deepseek.com' })
              .type(InputType.URL)
              .layoutWeight(1)
              .onChange((value) => {
                this.baseUrl = value;
              })
              .enabled(false)
          }
        }
        .padding(12)
        .backgroundColor($r('sys.color.comp_background_secondary')) // 灰色背景块区分高级设置
        .borderRadius(12)

        Blank() // 撑开空间，让按钮沉底（可选，这里不沉底也行）

        // 4. 保存并测试按钮
        Button(this.isTesting ? '正在连接...' : '保存并测试连接', { type: ButtonType.Capsule })
          .width('90%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .backgroundColor(this.buttonBg)
          .onClick(async () => {
            if (this.apiKey.trim().length === 0) {
              promptAction.showToast({ message: '请输入 API Key' });
              return;
            }

            this.isTesting = true;
            try {
              // 1. 保存配置到本地持久化 (LocalValues)
              const local = LocalValues.getInstance();
              await local.setDeepSeekApiKey(this.apiKey);
              await local.updateAIConfig(this.provider, this.model, this.baseUrl);

              promptAction.showToast({ message: '配置已保存，正在测试...' });

              // 2. 发起一次真实的 AI 请求进行测试
              // 使用一个非常简单的 prompt 来节省 Token 且快速验证
              const testPrompt = "请回复'OK'";
              await AIService.getInstance().extractTasks(testPrompt);

              promptAction.showToast({ message: '连接成功！AI 功能已就绪。' });

            } catch (e) {
              console.error(`AI Connection Error: ${JSON.stringify(e)}`);
              let msg = '未知错误';

              // 显式检查 e 是否为 Error 对象
              if (e instanceof Error) {
                msg = e.message;
              } else if (typeof e === 'string') {
                msg = e;
              } else {
                // 兜底处理：如果是其他对象，尝试转字符串
                msg = JSON.stringify(e);
              }
              if (msg.includes('401')) {
                msg = '鉴权失败，请检查 API Key';
              } else if (msg.includes('timeout')) {
                msg = '连接超时，请检查网络';
              }
              promptAction.showToast({ message: `连接失败: ${msg}` });
            } finally {
              this.isTesting = false;
            }
          })
      }
      .padding(16)
      .height('100%') // 占满高度
    }
    .title("AI 设置")
    .onReady((context: NavDestinationContext) => {
      this.pageStack = context.pathStack;
    })
  }
}