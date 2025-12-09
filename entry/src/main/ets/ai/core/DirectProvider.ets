import { http } from '@kit.NetworkKit';
import { LLMProvider } from './LLMProvider';
import { ChatRequest, ChatResponse } from '../model/AIModels';
import { BusinessError } from '@kit.BasicServicesKit';

export class DirectProvider implements LLMProvider {
  private apiKey: string;
  private baseUrl: string;

  constructor(apiKey: string, baseUrl: string) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
  }

  async chat(request: ChatRequest): Promise<ChatResponse> {
    const httpRequest = http.createHttp();
    const url = `${this.baseUrl}/chat/completions`; // 简单拼接，注意 baseUrl 结尾不要带 /

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(request),
        expectDataType: http.HttpDataType.STRING // 显式声明返回字符串
      });

      if (resp.responseCode !== 200) {
        throw new Error(`API Error: ${resp.responseCode} - ${resp.result}`);
      }

      // 解析 JSON
      const resultStr = resp.result as string;
      const chatResp = JSON.parse(resultStr) as ChatResponse;
      return chatResp;

    } catch (err) {
      // 统一错误处理
      let errorMsg = 'Unknown Network Error';
      if (err instanceof Error) {
        errorMsg = err.message;
      } else {
        const e = err as BusinessError;
        errorMsg = `Code: ${e.code}, Msg: ${e.message}`;
      }
      console.error('[DirectProvider]', errorMsg);
      throw new Error(errorMsg);
    } finally {
      httpRequest.destroy();
    }
  }
}