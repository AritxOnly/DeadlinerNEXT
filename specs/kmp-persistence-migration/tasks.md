# KMP Persistence Migration Tasks

## 阶段 1：规格冻结

- [x] 盘点 KMP Core schema、domain、Repository、state machine、changelog 与 sync façade
- [x] 盘点 HarmonyOS RDB、Preferences、SecureStorage、Widget 与同步入口
- [x] 对齐 iOS 的 runtime、adapter 与 migration report 形态；HarmonyOS 不保留业务 feature flag
- [x] 明确业务数据迁移范围和平台配置/凭据的非迁移边界
- [x] 确认最终跨端同步通道为 KMP Ktor WebDAV V3；ArkTS WebDAV 实现只在迁移回退期保留，最终删除
- [ ] 确认 AI 会话历史是否需要新增 KMP schema；当前仅迁移 memory/profile

## 阶段 2：基础设施（契约与观测）

- [x] 构建 ohosArm64 Core 库、NAPI lifecycle bridge 与独立 KMP DB runtime
- [x] 实现旧 RDB → V2 task/habit shadow import 与可重试状态
- [x] 定义 bridge v8 的 caller-owned JSON response ABI，并接入 V2 导入、Task/Habit/Capture/Memory/Profile ViewModel 与 Repository RPC、Overview、KMP AI utility、V3 WebDAV 同步及异步 NAPI Promise
- [x] 实现 runtime diagnostics：bridge 版本、KMP ready 状态和 category/task/habit/capture/memory/profile count；schema 版本与 typed RPC 仍待实现
- [x] 实现一次性 migration validation report；报告核对 bridge ready/version、V2 task/habit count 和 apply count，不充当业务开关

## 阶段 3：功能实现（领域迁移）

- [ ] Category：写入 KMP presets，提供 category RPC/adapter 与 V3 sync；本阶段不显示、不实现 HarmonyOS 分类 UI
- [x] Task/Subtask：提供 list/find/create/update/delete/action RPC，映射现有 DDLItem，切换 TaskRepository
- [x] Habit/Record：提供 CRUD/action/record RPC，切换 HabitRepository 和提醒读取路径；schedule RPC 尚未接入 HarmonyOS UI
- [x] Capture：将 inspiration 导入 capture，提供 Capture adapter，切换灵感入口
- [x] Memory/Profile：导入 MemoryBank Preferences，提供 KMP adapter，切换 AI memory/profile 读写
- [x] Search/Widget/AI tool：通过 KMP-backed ports 读取和修改数据，不直接访问 ArkData
- [x] Overview 统计：通过 KMP `OverviewViewModel` DTO 读取 summary、history、趋势、贡献图和月度指标；删除 ArkTS 对任务列表的统计重算
- [x] Task/Habit ViewModel intent：列表状态、刷新和 CRUD/action 经 KMP ViewModel 暴露，ArkTS Repository 仅执行提醒、Widget、同步调度与兼容 ID 副作用
- [x] AI utility：任务/习惯提取、配置验证、月度分析全部经 KMP Lifi/Ktor；删除 ArkTS `DirectProvider`、`ProxyProvider` 与 `LLMProvider`

## 阶段 4：验证与回写（同步与验证）

- [x] 以既有 KMP Ktor V3 changelog/WebDAV façade 替换 ArkTS `WebDavProvider` / `SyncService` 的业务同步，并删除旧快照协议代码；ArkTS 仅提供存储的 WebDAV 凭据。
- [x] 让鸿蒙同步入口解析 KMP V3/Ktor 结果并在远端失败时向 UI 返回失败；审计和删除不受 KMP 支持的同步模式入口。
- [x] 修复 V3 changelog 远端 apply 的外键依赖：category/task/habit 父记录先于引用它们的子记录；桥接返回结构化失败上下文。
- [x] 审计 AI：密钥配置留在 ArkTS 安全存储；推理网络、prompt/parser、Task/Habit tool 与 MemoryBank 业务路径使用 KMP Lifi/Ktor、ViewModel/Repository/store。
- [ ] 为每个领域验证 import count、UID、tombstone、重启与 V3 changelog LWW
- [ ] API 17+ 真机/模拟器与 iOS 完成跨端 CRUD、状态机、打卡、通知、Widget 与 Ktor/WebDAV V3 验收
- [x] 本批 Task/Habit ViewModel 同步 intent API 补 macOS integration test；未修改 schema 与既有 iOS 调用语义
- [x] 每批大改后构建 KMP Release 与 HarmonyOS HAP
- [x] 执行规格校验；大文件扫描记录现有超限文件且本批未向旧 `DatabaseHelper` / `SyncService` 增加逻辑
- [x] 回写 bridge version、构建结果与已切换领域
- [x] 删除旧 ArkTS snapshot merger、ArkTS WebDAV provider/protocol 与所有旧同步路径；保留仅承载 WebDAV 凭据的设置 UI
- [ ] 真机和 iOS 联调验收后，删除仅用于旧数据一次性导入的 ArkData RDB 代码
