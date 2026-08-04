# KMP Persistence Migration

## 背景

- 创建日期：2026-07-19
- 功能标识：`kmp-persistence-migration`
- 需求来源：以 `~/Codes/ProjectDeadliner/DeadlinerCore` 的 SQLDelight KMP 持久化层统一 HarmonyOS 与 iOS 的领域状态、Repository 和同步语义。

HarmonyOS 旧版以 ArkData RDB 的 `deadliner.db` 保存 task、subtask、habit、record 与 inspiration；AI memory/profile 另存于 Preferences。当前业务路径已改为 KMP Core 的 SQLDelight schema、UID-first 领域模型、state machine、Repository、V3 changelog façade 与 Ktor WebDAV transport；旧 RDB 仅在一次性迁移检查点读取。

## 目标

- 让 KMP Core 成为所有跨端业务持久化、状态机、Repository、同步合并和 changelog 的唯一事实来源；HarmonyOS 最终不再包含或调用 ArkData。
- 完整覆盖：category、task、subtask、habit、habit record、habit schedule、capture/inspiration、memory fragment、user profile、tombstone 与 changelog。
- HarmonyOS 与 iOS 使用同一套 KMP V3 changelog/WebDAV 同步语义；KMP 以 Ktor 执行 WebDAV I/O、变更合并和远端 apply，ArkTS 只保留安全凭据、UI 与系统集成。
- HarmonyOS 通过窄、版本化的 NAPI bridge 调用 KMP；ArkTS 不再维护业务 SQL、状态机、WebDAV 协议或冲突合并逻辑。
- HarmonyOS 的 Task/Habit 页面以 KMP `TaskListViewModel` / `HabitListViewModel` 的状态 DTO 为展示事实来源；用户 intent 经 KMP ViewModel 进入 Repository，ArkTS repository 仅保留平台提醒、Widget 刷新和旧数字 ID 投影。
- Overview 直接消费 KMP `OverviewViewModel` DTO；任务/习惯表单提取、配置验证和月度分析全部调用 KMP `AiUtilityService`，ArkTS 不再发起 LLM HTTP 请求或维护重复 prompt/parser。
- 先导入并核对，随后所有业务读写直接使用 KMP；不保留运行时 feature flag 或 ArkData 回退路径。
- 与 iOS 的 KMP store 语义对齐：UID-first、KMP state machine、Repository 原子写入与 V3 changelog LWW 合并。

## 非目标

- 本阶段不迁移平台配置、主题、隐私同意、页面布局、Widget 偏好、通知授权、账号令牌、AI 密钥或帮助资源；它们继续使用 Preferences / SecureStorage / 系统服务。
- V3 changelog/WebDAV 是跨 iOS / HarmonyOS 的最终业务同步通道，必须由 KMP 的 Ktor client 执行；删除 ArkTS 的 WebDAV 协议、快照和合并实现。
- 不重用或原地升级 ArkData 的 `deadliner.db`，也不删除旧表和旧仓储。
- 不把 KMP SQLite 直接暴露为 ArkData RDB，不在 ArkTS 复制 SQLDelight 查询或状态机。
- 不在缺少 API 17+ 真机/模拟器数据核对前默认启用任何 KMP 业务读写开关。

## 数据范围与映射

| 旧 HarmonyOS 来源 | KMP 目标 | 策略 |
| --- | --- | --- |
| `ddl_items` + `subtasks` | `task` + `task_subtask` | 保留既有 UID；缺失 UID 使用稳定导入 UID；状态统一由 KMP `TaskStateMachine` 处理。 |
| `habits` + `habit_records` | `habit` + `habit_record` | 保留 carrier UID；reminder 映射到 `HabitReminder`；后续补生成 `habit_schedule_item`。 |
| `inspiration_items` | `capture_item` | 以 `source=MANUAL` 迁移；消费状态按未消费处理，需在导入报告标记。 |
| `MemoryBank` fragments/profile | `memory_fragment` + `user_profile` | 从 Preferences 导出；毫秒时间戳转换为 ISO-8601；profile 使用稳定单例 UID。 |
| 旧 V2 cloud snapshot / `sync_state` | `legacy_v2_version` + KMP changelog | 首次兼容 V2 导入；后续由 KMP V3 changelog/WebDAV façade 合并并 apply 变更，旧 `sync_state` 不再参与新同步。 |
| category | `category` | 旧 HarmonyOS 没有业务 category 表；先写入 KMP presets，新增 category 后只存 KMP。 |

## 用户场景

1. 现有用户升级后，应用从旧 RDB 和 Preferences 一次性只读导入业务数据到 `deadliner_new_era.db`；原库保持不变且不再被业务仓储调用。
2. 创建、状态流转、子任务操作由 KMP Repository 与状态机执行，并产生 changelog。
3. 同一用户在 iOS 与多台 HarmonyOS 设备操作后，KMP 经 Ktor/WebDAV 交换 V3 changelog；KMP 以确定性的 LWW 规则合并，平台不维护另一套冲突规则。
4. 导入失败、Core 不可用或报告不一致时启动失败并保留旧库；不得将空 KMP 库标为成功，也不得回退到旧 ArkData 业务路径。

## 验收标准

- KMP `ohosArm64` Release 库可被打包、加载，并仅在 app files 的持久化绝对目录创建 `deadliner_new_era.db`。
- Bridge 具有版本协商、稳定 JSON request/response 协议、可诊断错误对象，并覆盖每个 KMP repository 所需的 list/find/create/update/delete/action/import/export/sync 操作。
- 每个领域导入是幂等的；报告至少包含 legacy/KMP 行数、UID 覆盖、tombstone 数、跳过/降级项和 schema/bridge 版本。
- 首批报告至少校验 bridge ready/version、V2 task/habit legacy 与 KMP 行数、导入 apply 数和校验时间；报告持久化在 Preferences，仅作为切换闸门，不承载业务数据。
- KMP Repository 是 task/habit 状态流转、子任务/record/schedule 原子写入及 changelog 的唯一执行者；ArkTS 不再写对应业务表。
- Task、Habit、Capture、Memory/Profile 与 V3 WebDAV sync 均无运行时切换开关；导入完成后 ArkTS 只调用 KMP bridge。
- Overview 的统计口径由 Core `OverviewViewModel` 唯一计算；ArkTS 只本地化标签和绘制图表，不再扫描任务列表重算完成、逾期、趋势或月度指标。
- AI 模型密钥仍由平台安全存储提供；推理网络、会话编排、任务/习惯提取、配置验证和月度分析均由 KMP Lifi/Ktor 实现，其业务工具必须经 KMP ViewModel/Repository，长期记忆和用户画像必须经 KMP memory/profile store。
- Task/Habit 的列表读取、刷新和用户 intent 由 KMP ViewModel 暴露；OHOS bridge 不得另外实现状态机或直接拼装一套与 ViewModel 分叉的 UI 状态。
- 同步调用必须消费 KMP WebDAV/Ktor 返回的结构化结果；不能把远端失败当作本地同步成功。
- 远端 changelog 的 parent/child 记录必须按外键依赖安全应用；无法满足依赖时，KMP 返回包含 table、record 与缺失父引用的结构化失败，不能因 SQLite `FOREIGN KEY` 异常退化为通用 toast。
- API 17+ 真机或模拟器完成导入、重启、CRUD、状态机、打卡，以及与 iOS 的 Ktor/WebDAV V3 双向同步验收；旧 RDB 与 KMP 数据可抽样核对。

## 风险与约束

- 这是 breaking data-layer change；保护提交为 `e935b0d`，迁移工作从 `refactor/kmp` 开始。
- KMP schema 使用字符串 UID、soft delete 和外键；旧 RDB 使用数字 ID 与 V2 版本字段，不能原地升级。
- 当前 bridge v8 支持 lifecycle、V2 task/habit 导入、diagnostics、Task/Habit/Capture/Memory/Profile ViewModel 与 Repository RPC、Overview DTO、KMP AI utility，以及 V3 changelog WebDAV 同步；同步 JSON response 使用 caller-owned buffer，可能执行网络或聚合工作的 NAPI 入口使用 Promise。
- Core 的跨端 `OverviewViewModel` 已作为 HarmonyOS 统计数据的唯一来源；ArkTS `OverviewUtils` 只保留绘图所需的展示类型，不再计算业务统计口径。
- V3 指既有的 `ChangeLogSyncFacade` / `WebDavChangeLogSyncFacade` 协议；不得新增平行 snapshot 协议或改变现有 commonMain 业务逻辑。capture、memory、profile 的 changelog 覆盖应作为原协议的受测扩展处理。
- 本轮优先复用现有 commonMain ViewModel 与 `AiUtilityService`；若为 OHOS intent 接线补充 commonMain API，只允许添加不改变 iOS 既有调用语义的薄入口，并补回归测试。
- `inspiration_items`、MemoryBank profile 和旧 habit carrier 的语义并非一一对应；任何默认值或降级必须出现在迁移报告中，不能静默丢失。
- 所有 `.ets` 实现必须遵守 ArkTS 约束；新代码按 bridge、DTO、adapter、migration mapper 分文件，禁止继续膨胀 `DatabaseHelper.ets`、`SyncService.ets`。
- ArkData 的 RDB 仅作为一次性迁移输入；必须继续验证 KMP store、iOS/HarmonyOS V3 WebDAV 同步、通知、Widget 和 AI tool。分类数据仍迁移并同步，但本阶段 HarmonyOS 不显示、不编辑分类 UI。
