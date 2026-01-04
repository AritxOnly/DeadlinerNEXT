import { LocalValues } from '../common/local/LocalValues';
import { DirectProvider } from './core/DirectProvider';
import { LLMProvider } from './core/LLMProvider';
import { ChatRequest, Message, MixedResult, AITask, AIHabit } from './model/AIModels';

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

  /**
   * 核心功能：智能提取习惯
   */
  async extractHabits(text: string, preferredLang: string = 'zh-CN'): Promise<AIHabit[]> {
    const provider = this.getProvider();
    const local = LocalValues.getInstance();
    const modelId = local.getAIModel();

    // --- 构造中文 System Prompt (习惯专用版) ---
    const systemPrompt = `
你是一个追求极致效率的习惯养成助手 (Deadliner AI)。
当前时间：${new Date().toLocaleString('zh-CN', { hour12: false })}
用户语言：${preferredLang}

任务：将用户的自然语言转化为“习惯(Habit)”条目。

**字段说明与提取原则：**
1. **name (习惯名)**：
   - 极简主义，提取核心关键词。例如 "背单词", "跑步", "喝水"。
   - 去除冗余词，字数控制在 2-8 个字。

2. **period (周期)**：
   - 必须是以下三个值之一： "DAILY" (每日), "WEEKLY" (每周), "MONTHLY" (每月)。
   - 默认值：如果未明确提及周期，默认为 "DAILY"。
   - 示例："每天跑步" -> DAILY; "每周去健身房" -> WEEKLY。

3. **timesPerPeriod (单周期频次)**：
   - 表示在上述周期内需要完成的次数或数量。
   - 必须是整数，默认值为 1。
   - 示例："每天背20个单词" -> period: DAILY, timesPerPeriod: 20; "每周运动3次" -> period: WEEKLY, timesPerPeriod: 3。

4. **goalType (目标类型)**：
   - "PER_PERIOD" (坚持型/周期型): 只要每个周期完成指定次数即可。这是默认类型。
   - "TOTAL" (定量型/总目标型): 有一个宏大的总目标，完成后习惯即终止。
   - 判别依据：如果用户提到了“总共要完成X次/X个”，则为 TOTAL。

5. **totalTarget (总目标)**：
   - 仅当 goalType 为 "TOTAL" 时需要此字段。表示总共要完成的数量。

**示例参考：**
- 输入："我要每天背50个单词"
  -> { "name": "背单词", "period": "DAILY", "timesPerPeriod": 50, "goalType": "PER_PERIOD" }
- 输入："每周去三次健身房"
  -> { "name": "健身房运动", "period": "WEEKLY", "timesPerPeriod": 3, "goalType": "PER_PERIOD" }
- 输入："我要在一个月内读完这本300页的书，每天读10页"
  -> { "name": "读书", "period": "DAILY", "timesPerPeriod": 10, "goalType": "TOTAL", "totalTarget": 300 }

请返回纯 JSON：
{
  "primaryIntent": "ExtractHabits",
  "habits": [
    {
      "name": "习惯名称",
      "period": "DAILY",
      "timesPerPeriod": 1,
      "goalType": "PER_PERIOD"
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

      return resultObj.habits ?? [];

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