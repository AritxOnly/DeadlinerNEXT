import { LengthMetrics } from '@kit.ArkUI'
import { i18n } from '@kit.LocalizationKit'
import { AIService } from '../../ai/AIServcice'
import { AITask } from '../../ai/model/AIModels'
import { AddTaskParams } from '../routes/main/modify/AddTaskPage'
import { LoginPanelView } from './LoginPanelView'

// 定义简单的消息模型
export interface AIChatMessage {
  id: string
  role: 'ai' | 'user'
  content: string
  tasks?: AITask[]
}

@Component
export struct AIPanelView {
  @Consume('appPathStack') appPathStack: NavPathStack;

  @State inputText: string = ''
  @State isLoading: boolean = false // 新增：加载状态

  @Require onDismissPanel: () => void;

  @State messages: AIChatMessage[] = [
    {
      id: '1',
      role: 'ai',
      content: '你好！我是 Deadliner AI。告诉我你的计划，我来帮你创建任务。'
    }
  ]

  private scroller: Scroller = new Scroller()

  /**
   * 核心逻辑：发送消息并调用 AI
   */
  async sendMessage() {
    const text = this.inputText.trim();
    if (!text || this.isLoading) return;

    // 1. 立即上屏用户消息
    const userMsg: AIChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      content: text
    };
    this.messages.push(userMsg);
    this.inputText = ''; // 清空输入框
    this.isLoading = true;
    this.scrollToBottom();

    try {
      // 2. 调用 AIService
      // 获取系统语言，确保 DeepSeek 知道怎么称呼任务
      const sysLang = i18n.System.getSystemLanguage();
      const tasks = await AIService.getInstance().extractTasks(text, sysLang);

      // 3. 格式化 AI 返回的结果为文本
      const aiResponseText = this.formatAIResponseText(tasks);

      const aiMsg: AIChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'ai',
        content: aiResponseText,
        tasks: tasks
      };
      this.messages.push(aiMsg);

    } catch (err) {
      // 4. 错误处理
      const errorMsg: AIChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'ai',
        content: `抱歉，遇到了一些问题：${err.message || '网络连接失败'}`
      };
      this.messages.push(errorMsg);
    } finally {
      this.isLoading = false;
      this.scrollToBottom();
    }
  }

  /**
   * 辅助方法：将 Task 对象转为可读的对话文本
   */
  formatAIResponseText(tasks: AITask[]): string {
    if (!tasks || tasks.length === 0) return '抱歉，没有识别到具体任务。';
    return `已为您识别到 ${tasks.length} 个任务：`;
  }

  scrollToBottom() {
    // 稍微延迟一点，等待 UI 渲染完成
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  @Builder
  RealAIContent() {
    Column() {
      // 1. 对话列表区域
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (msg: AIChatMessage) => {
          ListItem() {
            this.MessageBubble(msg)
          }
        }, (msg: AIChatMessage) => msg.id)
      }
      .layoutWeight(1) // 占据剩余空间
      .width('100%')
      .backgroundColor(Color.Transparent)
      .padding({ left: 16, right: 16, top: 10 })
      .alignListItem(ListItemAlign.Start)

      // 2. 底部输入区域
      Row() {
        TextInput({ text: $$this.inputText, placeholder: '输入任务或计划...' })
          .layoutWeight(1)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .height(40)
          .enabled(!this.isLoading) // 加载时禁用输入
          .onSubmit(() => {
            this.sendMessage()
          })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          // 根据加载状态切换图标
          if (this.isLoading) {
            LoadingProgress()
              .width(20).height(20)
              .color($r('sys.color.icon_on_primary'))
          } else {
            SymbolGlyph($r('sys.symbol.arrow_up'))
              .fontSize(24)
              .fontColor([$r('sys.color.icon_on_primary')])
          }
        }
        .width(40)
        .height(40)
        .margin({ left: 12 })
        .backgroundColor(this.inputText.length > 0 ? $r('app.color.brand') : $r('sys.color.comp_background_tertiary')) // 有文字时高亮
        .enabled(!this.isLoading && this.inputText.length > 0)
        .onClick(() => {
          this.sendMessage()
        })
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 36
      })
      .border({ width: { top: 0.5 }, color: $r('sys.color.comp_divider') })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }

  // 消息气泡构建器 (保持不变，略微优化了显示)
  @Builder
  MessageBubble(msg: AIChatMessage) {
    Row() {
      if (msg.role === 'ai') {
        // AI 消息样式 (左侧)
        SymbolGlyph($r('sys.symbol.AI')) // 请确保你有这个 Symbol，或者是 sys.symbol.sparkles
          .fontSize(24)
          .fontColor([$r('app.color.brand')])
          .margin({ right: 8, top: 4 })
          .alignSelf(ItemAlign.Start)

        Column({ space: 8 }) {
          // 1. 气泡文本
          Text(msg.content)
            .fontSize(16)
            .fontColor($r('sys.color.font_primary'))
            .backgroundColor($r('sys.color.comp_background_secondary')) // 气泡背景
            .padding(12)
            .borderRadius({
              topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16
            })

          // 2. 【新增】任务卡片列表
          if (msg.tasks && msg.tasks.length > 0) {
            ForEach(msg.tasks, (task: AITask) => {
              this.TaskCard(task)
            })
          }
          
          this.AILabel()
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      } else {
        // 用户消息样式 (右侧)
        Blank()

        Text(msg.content)
          .fontSize(16)
          .fontColor($r('sys.color.font_on_primary'))
          .backgroundColor($r('app.color.brand'))
          .padding(12)
          .borderRadius({
            topLeft: 16,
            topRight: 4,
            bottomLeft: 16,
            bottomRight: 16
          })
          .lineHeight(24)
          .constraintSize({ maxWidth: '80%' })
          .copyOption(CopyOptions.LocalDevice)
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .justifyContent(msg.role === 'ai' ? FlexAlign.Start : FlexAlign.End)
  }

  @Builder
  AILabel() {
    Row({ space: 4 }) {
      Text('AI生成内容，请核查')
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .padding({ right: 4, top: 2 })
    .opacity(0.8)
  }

  @Builder
  TaskCard(task: AITask) {
    Column() {
      // 任务信息
      Row() {
        Column() {
          Text(task.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (task.dueTime) {
            Text(`截止: ${task.dueTime}`)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 添加按钮
        Button('去创建')
          .type(ButtonType.Capsule)
          .controlSize(ControlSize.SMALL)
          .backgroundColor($r('app.color.brand'))
          .height(28)
          .fontSize(12)
          .onClick(() => {
            const params: AddTaskParams = {
              name: task.name,
              note: task.note,
              dueTime: task.dueTime
            };
            this.appPathStack.pushPathByName('addTask', params);
            this.onDismissPanel()
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('sys.color.background_primary')) // 卡片背景色（比气泡略亮或略暗）
      .borderRadius(12)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS) // 增加一点阴影让它浮起来

      // 如果有备注，显示备注
      if (task.note) {
        Divider().color($r('sys.color.comp_divider')).margin({ top: 8, bottom: 8 })
        Text(task.note)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .margin({ top: 4 })
    .width('85%') // 稍微缩一点，增加层次感
  }

  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;

  build() {
    Column() {
      if (this.isLoggedIn) {
        // 场景 A：已登录 -> 显示真正的 AI 功能
        this.RealAIContent()
      } else {
        // 场景 B：未登录 -> 显示登录面板
        // LoginPanelView 会处理登录逻辑并在成功后修改 isLoggedIn 为 true
        LoginPanelView()
      }
    }
    .width('100%')
    .height('100%')
  }
}