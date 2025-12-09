import { http } from '@kit.NetworkKit';
import { LLMProvider } from './LLMProvider';
import { ChatRequest, ChatResponse } from '../model/AIModels';

export class ProxyProvider implements LLMProvider {
  private appSecret: string;
  private deviceId: string;
  private apiBase: string;

  constructor(apiBase: string, appSecret: string, deviceId: string) {
    this.apiBase = apiBase;
    this.appSecret = appSecret;
    this.deviceId = deviceId;
  }

  async chat(request: ChatRequest): Promise<ChatResponse> {
    // 强制关闭 stream，因为我们目前用非流式
    const requestBody: ChatRequest = {
      model: request.model,
      messages: request.messages,
      stream: false, // 强制关闭流式
      temperature: request.temperature
    };

    const patchedRequest = requestBody;

    const httpRequest = http.createHttp();
    // 处理 URL 拼接逻辑
    const cleanBase = this.apiBase.endsWith('/') ? this.apiBase.slice(0, -1) : this.apiBase;
    const url = `${cleanBase}/chat/completions`;

    try {
      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'X-Deadliner-Key': this.appSecret,
          'X-Deadliner-Device': this.deviceId
        },
        extraData: JSON.stringify(patchedRequest),
        expectDataType: http.HttpDataType.STRING
      });

      if (resp.responseCode !== 200) {
        throw new Error(`Proxy Error: ${resp.responseCode} - ${resp.result}`);
      }

      const resultStr = resp.result as string;
      return JSON.parse(resultStr) as ChatResponse;

    } catch (err) {
      const errorMsg = JSON.stringify(err);
      console.error('[ProxyProvider] Unknown error:', errorMsg);
      throw new Error(`Network Error: ${errorMsg}`);
    } finally {
      httpRequest.destroy();
    }
  }
}