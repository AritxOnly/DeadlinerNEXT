export interface Message {
  role: string;
  content: string;
}

export interface ChatRequest {
  model: string;
  messages: Message[];
  stream?: boolean;
  temperature?: number;
}

export interface ChatResponse {
  choices: Choice[];
  usage?: Usage;
}

export interface Choice {
  message: Message;
  finish_reason?: string;
}

export interface Usage {
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
}

// --- 2. 业务结果模型 (ResultModel.kt) ---

// 意图枚举
export enum IntentType {
  ExtractTasks = 'ExtractTasks',
  PlanDay = 'PlanDay',
  SplitToSteps = 'SplitToSteps'
}

// 对应 MixedResult，这是 LLM 最终输出的 JSON 结构
export interface MixedResult {
  primaryIntent: string; // "ExtractTasks" | "PlanDay" | "SplitToSteps"
  tasks?: AITask[];
  habits?: AIHabit[];
  planBlocks?: PlanBlock[];
  steps?: SplitStepsResult[];
}

export interface AITask {
  name: string;
  dueTime: string; // "yyyy-MM-dd HH:mm"
  note: string;
}

export interface AIHabit {
  name: string;
  period: 'DAILY' | 'WEEKLY' | 'MONTHLY'; // 对应 HabitPeriod
  timesPerPeriod: number; // 每次/频次
  goalType: 'PER_PERIOD' | 'TOTAL'; // 对应 HabitGoalType
  totalTarget?: number; // 如果是 TOTAL 类型，需要总目标
}

export interface PlanBlock {
  title: string;
  start: string; // "yyyy-MM-dd HH:mm"
  end: string;
  location?: string;
  energy?: string; // low/med/high
  linkTask?: string;
}

export interface SplitStepsResult {
  title: string;
  checklist: string[];
}

// --- 3. 检查接口模型 (DeadlinerCheckUtils.kt) ---
export interface DeadlinerCheckResp {
  // 根据你实际的 json 补全，这里假设有一个 status 或 quota
  valid: boolean;
  message?: string;
  remainingQuota?: number;
}