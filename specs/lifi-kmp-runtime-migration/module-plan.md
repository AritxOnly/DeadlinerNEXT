# Lifi KMP Runtime Migration Module Plan

## 模块拆分

1. **KMP Lifi runtime bridge**
   - 在 `DeadlinerCore/shared/src/ohosArm64Main/.../bridge` 新建独立 Lifi C ABI。
   - 持有 KMP `DeadlinerCore` 会话、将 `CoreEvent` 序列化为稳定 JSON，并把
     Memory/Profile repository 适配为 `MemoryStorePort`。
   - 复用 commonMain 的 `LifiAIComponent` 和 OHOS `KtorLlmClient`。

2. **NAPI contract**
   - 在 Harmony `napi_init.cpp` 动态解析 Lifi C ABI，并以现有 caller-owned
     JSON buffer 约定导出 ArkTS 函数。
   - 类型声明单独落在 `libdeadliner_persistence`，不再维护 `libffi_ohos` API。

3. **ArkTS AI adapter**
   - `DeadlinerCoreService` 保持页面调用面，内部改为 KMP bridge。
   - `DeadlinerToolAdapter` 继续作为平台工具执行器，但业务数据来自 KMP repository。
   - 删除 Rust-memory snapshot 推拉和事件轮询对 Rust 句柄的依赖。

4. **Rust removal and validation**
   - 清理 CMake、oh-package/类型声明和动态库打包引用。
   - 对照 iOS/KMP 的 AI 结果、工具请求和 V3 changelog 进行设备验证。

## 平台映射

| 层 | KMP Core | HarmonyOS |
| --- | --- | --- |
| AI 业务 | `commonMain/domain/ai`, `commonMain/lifi`, `interfaces/DeadlinerCore` | 无 |
| OHOS 网络/ABI | `ohosArm64Main/lifi`, `ohosArm64Main/bridge` | `entry/src/main/cpp/napi_init.cpp` |
| UI 与系统工具 | 无 | `entry/src/main/ets/ai/core`, `DeadlinerToolAdapter`, `AIPanelView` |
| 存储/同步 | KMP repositories + V3 changelog | 一次性迁移数据源，不参与 AI 业务 |

## 文件拆分策略

- Lifi ABI 放入新的 Kotlin bridge 文件，不向已有持久化桥接文件继续追加会话逻辑。
- NAPI 仅添加小型函数指针和 JSON 转发；重复缓冲区读写应抽取公共 helper。
- ArkTS 服务超过 1000 行时，事件 JSON 映射和进度文案拆至同目录 helper。

## 风险点

- `CoreEvent` 是 sealed model，桥接前必须定义版本化 JSON schema，避免直接依赖
  Kotlin 类型名。
- KMP `DeadlinerCore` 当前以 Flow 发事件；C ABI 需要明确同步执行和事件 drain 的
  线程/顺序语义。
- 删除 Rust 前不得引入 fallback；若 KMP 路径验证失败，应修复 KMP bridge 而非保留
  双运行时。

## 模块拆分

- `contract`：
- `domain`：
- `presentation`：
- `infra`：

## 平台映射

- iOS：
- HarmonyOS：
- Android：

## 文件拆分策略

- 单个核心文件尽量不超过 1000 行有效代码
- 若必须逃逸，先申请开发者批准

## 风险点

- 
