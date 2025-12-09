import { LocalValues } from '../common/local/LocalValues';
import { DirectProvider } from './core/DirectProvider';
import { LLMProvider } from './core/LLMProvider';
import { ChatRequest, Message, MixedResult, AITask } from './model/AIModels';

export class AIService {
  private static instance: AIService;

  private constructor() {}

  public static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  private getProvider(): LLMProvider {
    const local = LocalValues.getInstance();
    const apiKey = local.getDeepSeekApiKey();
    const baseUrl = local.getAIBaseUrl();

    if (!apiKey) {
      throw new Error('请先在设置中填写 DeepSeek API Key');
    }
    return new DirectProvider(apiKey, baseUrl);
  }

  /**
   * 核心功能：智能提取任务
   */
  async extractTasks(text: string, preferredLang: string = 'zh-CN'): Promise<AITask[]> {
    const provider = this.getProvider();
    const local = LocalValues.getInstance();
    const modelId = local.getAIModel();

    // --- 构造中文 System Prompt (极致简洁版) ---
    const systemPrompt = `
你是一个追求极致效率的日程管理助手 (Deadliner AI)。
当前时间：${new Date().toLocaleString('zh-CN', { hour12: false })}
用户语言：${preferredLang}

任务：将用户的自然语言转化为“待办清单(To-Do List)”条目。

**提取原则：**
1. **Name (任务名)**：**极简主义**。
   - 提取**核心关键词**，像写便利贴一样简练。
   - 去除“帮我”、“记得”、“打算”、“需要”等冗余词。
   - 不强制语法结构，动词短语（如“买咖啡”）或名词短语（如“微积分考试”）皆可。
   - 字数控制在 **2-8个字** 最佳，绝不超过15字。

2. **Note (备注)**：
   - 如果任务名无法涵盖所有细节（如具体地点、包含的物品、特定人名），请放入备注。
   - 如果任务名已足够清晰，备注留空。

3. **DueTime (时间)**：
   - 严格基于当前时间推算 "yyyy-MM-dd HH:mm"。
   - 如果未提及具体时刻，留空 ""。

**示例参考：**
- 输入："记得提醒我下周三要把那个周报发给老板" -> Name: "发送周报", Note: "发给老板"
- 输入："明天下午三点有个部门会议在201会议室" -> Name: "部门会议", Note: "201会议室"
- 输入："去超市买点鸡蛋和牛奶" -> Name: "超市购物", Note: "买鸡蛋、牛奶"

请返回纯 JSON：
{
  "primaryIntent": "ExtractTasks",
  "tasks": [
    {
      "name": "极简标题",
      "dueTime": "yyyy-MM-dd HH:mm",
      "note": "补充细节"
    }
  ]
}
`;

    const messages: Message[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: text }
    ];

    const request: ChatRequest = {
      model: modelId,
      messages: messages,
      temperature: 0.1 // 保持低温度以确保格式稳定
    };

    try {
      const response = await provider.chat(request);

      const content = response.choices[0]?.message?.content;
      if (!content) {
        throw new Error('AI 返回内容为空');
      }

      console.info('[AIService] Raw Response:', content);

      const cleanJson = this.cleanJsonString(content);
      const resultObj = JSON.parse(cleanJson) as MixedResult;

      return resultObj.tasks ?? [];

    } catch (err) {
      console.error('[AIService] Extract failed:', JSON.stringify(err));
      if (err instanceof Error) throw err;
      throw new Error('AI 处理失败，请检查网络或配置');
    }
  }

  private cleanJsonString(str: string): string {
    let result = str.trim();
    if (result.startsWith('```json')) {
      result = result.substring(7);
    } else if (result.startsWith('```')) {
      result = result.substring(3);
    }
    if (result.endsWith('```')) {
      result = result.substring(0, result.length - 3);
    }
    return result.trim();
  }
}