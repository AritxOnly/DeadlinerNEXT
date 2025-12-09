import { ChatRequest, ChatResponse } from '../model/AIModels';

export interface LLMProvider {
  /**
   * 发送聊天请求
   */
  chat(request: ChatRequest): Promise<ChatResponse>;
}