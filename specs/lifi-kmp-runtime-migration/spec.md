# Lifi KMP Runtime Migration

## 背景

DeadlinerCore 已包含 Lifi 的领域模型、Agent 编排、工具调用续传、记忆接口和
OHOS Ktor LLM 客户端。鸿蒙端却仍通过 `libffi_ohos.so` 中的 Rust
`DeadlinerCore` 执行这些业务，再把 `MemoryBank` 快照同步回 KMP 数据库。
这使同一业务存在两套运行时，并阻止删除 Rust FFI。

## 目标

- 让鸿蒙 AI 面板直接调用 `libDeadlinerCore.so` 暴露的 KMP Lifi C ABI。
- 使用既有 KMP `interfaces/DeadlinerCore`、`LifiAIComponent`、Ktor 客户端和
  KMP Memory/Profile repository；不得在 ArkTS 重写编排、记忆或网络逻辑。
- 保持现有工具请求—ArkTS 执行—工具结果续传的交互协议和用户可见进度。
- 与 KMP V3 changelog 的记忆/Profile 同步保持同一数据源。
- 移除 `libffi_ohos.so`、Rust FFI 类型声明和构建依赖；设备验证用于确认运行时行为。

## 非目标

- 不引入新的 AI 协议、第二套 AI 数据库、fallback 或运行时开关。
- 不改变 iOS 已经使用的 KMP Lifi 业务语义。
- 不在本迁移中扩展新的 AI 工具或改变模型供应商设置页面。

## 用户场景

用户在鸿蒙 AI 面板要求创建任务。KMP Lifi 通过 Ktor 调用模型，返回一个
待执行的 `create_task` 工具请求；ArkTS 使用既有 KMP-backed repository 执行，
再将结果交回同一 KMP Lifi 会话，最终回复和记忆只写入 KMP 数据库并可通过 V3
changelog 同步到 iOS。

## 验收标准

- 鸿蒙 AI 输入、工具续传、任务/习惯建议、记忆提交和 `extractTasks` 均不加载
  `libffi_ohos.so`。
- API Key、base URL、模型、平台和时区仅作为配置传入 KMP；LLM HTTP 使用
  Core 内的 Ktor 实现。
- AI 的 Memory/Profile 写入 KMP repository，并随既有 V3 WebDAV changelog
  同步；不会覆盖既有鸿蒙原始数据。
- KMP C ABI 对无效配置、未初始化数据库和 AI 异常返回可读的结构化错误，ArkTS
  不通过 Rust 或原生存储兜底。
- Release Core 与 HAP 均能构建；在鸿蒙设备完成一次无 Rust FFI 的 AI 工具调用
  和一次 V3 WebDAV 同步联调。

## 风险与约束

- 这是运行时替换，必须先用同一输入/工具续传路径验证事件顺序和 JSON schema，
  再删除 Rust 产物。
- `DeadlinerPersistenceCApi.kt` 已接近桥接职责上限；新增 Lifi bridge 必须拆到
  独立文件，避免继续放大持久化 API 文件。
- ArkTS 只处理 UI 映射和受平台约束的工具执行；不得保存 AI 业务状态。

## 背景

- 创建日期：2026-08-03
- 功能标识：`lifi-kmp-runtime-migration`
- 需求来源：

## 目标

- 

## 非目标

- 

## 用户场景

1. 

## 验收标准

- 

## 风险与约束

- 
