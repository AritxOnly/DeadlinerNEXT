# KMP Persistence Migration Module Plan

## 模块拆分

- `kmp-domain-and-repository`：`DeadlinerCore/shared/src/commonMain` 的 schema、domain、state machine、Repository、changelog 和 sync façade；业务规则只能在此层新增或修改。
- `kmp-ohos-bridge`：`shared/src/ohosArm64Main/.../bridge/` 的 Kotlin/Native C ABI，及 `entry/src/main/cpp/` 的 NAPI adapter。提供一个版本化 JSON RPC 边界、错误结果和内存安全的 response buffer，不暴露 SQL。
- `ohos-persistence-contract`：`entry/src/main/ets/common/kmp/` 的 ArkTS DTO、bridge client、runtime 与 ViewModel adapters；将 native 返回映射为现有页面模型，不复制聚合或状态机。
- `ohos-migration`：`entry/src/main/ets/common/migration/` 的 legacy exporters、KMP importers、validation report、migration state；全部对旧数据只读。
- `ohos-adapters`：`entry/src/main/ets/common/repository/` 的 Task、Habit、Inspiration/Capture、Memory/Profile adapter；只做 UI 模型适配，不含 legacy 回退。
- `kmp-webdav-v3`：既有 `commonMain` 的 V3 changelog/WebDAV façade；复用 Ktor transport，以 changelog LWW 处理 merge、remote apply 与 conditional write。不得引入平行 snapshot 协议。
- `kmp-overview`：既有 `commonMain` 的 `OverviewViewModel` 是跨端统计聚合权威；OHOS bridge 仅投影其稳定 DTO，ArkTS 不得重新扫描 task/habit 数据。
- `ohos-ai-integration`：AI 密钥与平台配置保留 ArkTS；网络、prompt、parser、对话编排和 utility 全部由 KMP Lifi/Ktor 提供。`DeadlinerToolAdapter` 和 `MemoryBank` 只通过 KMP ViewModel/Repository / memory-profile bridge 访问业务数据。
- `platform-integration`：启动初始化、通知/Widget 刷新、迁移诊断页；平台 API 在此层，不进入 KMP Repository。

## 分阶段切换

1. **契约与观测**：bridge JSON RPC、runtime health、schema/bridge 诊断与一次性导入报告；不设置业务切换开关。
2. **分类与任务**：category presets，task/subtask 导入核对，切换 list/CRUD/action；KMP state machine 替代 ArkTS 状态机。
3. **习惯**：habit/record/reminder/schedule 导入与切换；通知调度读取 KMP adapter。
4. **收集箱与 AI 记忆**：inspiration → capture，Preferences memory/profile → KMP；保留 UI 会话历史在平台 Preferences，除非单独为其增加 KMP schema。
5. **V3 WebDAV 同步**：接入既有 KMP Ktor changelog façade，令 iOS 与 HarmonyOS 使用相同 V3 path/payload；KMP 处理 payload、remote apply、version 与 conflict resolve，ArkTS 仅传递 WebDAV 凭据；补齐 capture/memory/profile 支持。
6. **ArkData 退役**：迁移完成后业务读写已直接使用 KMP；删除旧 V2 ArkTS sync 和 ArkTS WebDAV 协议代码，保留仅承载凭据的设置 UI，并在真机/iOS 验收后移除旧 RDB 迁移代码。
7. **统计、AI 与 ViewModel 收敛**：将 Overview DTO 接入页面，令 HarmonyOS 只绘制 Core 的统计快照；任务/习惯表单提取、配置验证和月度分析切换到 KMP `AiUtilityService`；Task/Habit 展示状态与 intent 统一经 KMP ViewModel，ArkTS adapter 仅负责 UI 模型和平台副作用。

## 平台映射

- **KMP common**：`shared/src/commonMain/sqldelight/com/deadliner/db/`、`shared/src/commonMain/kotlin/com/deadliner/{domain,db/repository,sync}/`；iOS 和 HarmonyOS 都只调用 repository API。
- **KMP HarmonyOS native**：`shared/src/ohosArm64Main/kotlin/com/deadliner/{db,bridge}/`；由 CPF KMP-CMP 产出 `libDeadlinerCore.so`。
- **HarmonyOS**：`entry/src/main/cpp/` 负责 NAPI 与 ABI buffer，`entry/src/main/ets/common/kmp/` 负责 typed client，`common/migration/` 负责一次性导入，`common/repository/` 只保留 model adaptation；旧 `common/sync` 已删除。
- **iOS**：保持 `Deadliner/Data/Persistence/KMP/` 的 runtime、store 与 feature flag 结构；后续同步 KMP RPC/DTO 语义而不倒退回本地 SQL。

## 文件拆分策略

- 每个 RPC domain 单独定义 request/response DTO：`TaskRpc`、`HabitRpc`、`CaptureRpc`、`MemoryRpc`、`SyncRpc`；不得用一个无类型的大 JSON switch 文件承载所有业务。
- migration exporter 按 task、habit、capture、memory/profile 分文件；validation report 独立建模。
- 首批 validation report 由 `KmpMigrationValidation.ets` 持久化，仅作为迁移完成记录，不能成为业务数据源或运行时开关。
- 每个 ArkTS adapter 小于 1000 行；禁止修改现有超限的 `DatabaseHelper.ets` 与 `SyncService.ets` 承载新逻辑。
- Core 的 schema 改动必须附 migration `.sqm` 与 commonTest；bridge ABI 变更必须提高 bridge version 并在 HarmonyOS types 中同步。
- Overview bridge DTO 与 V3 sync outcome 均单独建模；不得把统计或同步结果塞入 task/habit JSON。
- AI utility 使用异步 NAPI Promise，避免 Ktor 请求或 Overview 聚合占用 ArkUI 线程；每种结果使用明确 DTO，不恢复 ArkTS `DirectProvider`。

## 风险点

- Kotlin/Native 返回变长 JSON 时需明确 buffer ownership，禁止由 NAPI 猜测指针生命周期。
- 旧 numeric ID 在切换后仅作为 UI compatibility projection，KMP UID 才是持久化主键；不能把 numeric ID 写回 KMP schema。
- 任务与习惯切换必须同时处理通知、Widget、搜索、AI tool adapter 和 V3 WebDAV，不能只替换页面列表。
- MemoryBank 当前 JSON 格式使用毫秒时间戳且没有 tombstone；迁移后首次删除要由 KMP changelog 产生 tombstone。
- V3 WebDAV remote apply 必须覆盖 category、task、subtask、habit、record、schedule、capture、memory、profile 的依赖顺序和 LWW 测试；分类暂不暴露 HarmonyOS UI，但不得在导入或同步中丢失。
