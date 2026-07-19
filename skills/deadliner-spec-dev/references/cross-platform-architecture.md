# Cross-Platform Architecture

## 总原则

- 先按能力拆模块，再按平台落文件。
- iOS 采用 DDD 分层。
- HarmonyOS 采用简单分层，避免过度抽象。
- Android 采用简单分层，优先贴近现有 `data / model / ui` 习惯。

## iOS 参考

参考仓库：`~/Codes/iOS/Deadliner`

现有结构重点：

- `Deadliner/Core/Application/Ports`
- `Deadliner/Core/Application/UseCases`
- `Deadliner/Core/Domain/Models`
- `Deadliner/Data/Repositories`
- `Deadliner/Features/<Feature>`

新增功能优先落位：

- 领域对象与规则：`Core/Domain`
- 业务编排：`Core/Application/UseCases`
- 数据接入：`Data/Repositories`
- SwiftUI 页面与组件：`Features/<Feature>`

## HarmonyOS 参考

参考仓库：`~/Codes/HarmonyOS/Deadliner`

现有结构重点：

- `entry/src/main/ets/model`
- `entry/src/main/ets/common/repository`
- `entry/src/main/ets/common/data`
- `entry/src/main/ets/pages/routes/<feature>`
- `entry/src/main/ets/pages/components`

新增功能优先落位：

- 数据模型：`model` 或 feature 下 `model`
- 数据/服务逻辑：`common/repository`、`common/data` 或 feature service/helper
- 页面：`pages/routes/<feature>`
- 复用组件：`pages/components` 或 feature 自己的 `components`

HarmonyOS 代码守则：

- 修改 `.ets` 前先加载 `arkts-grammar-standards`
- 涉及 UI/布局/状态时再加载 `arkui-knowledge`
- 不把 ArkTS 当成通用 TypeScript 使用

## Android 参考

参考仓库：`~/Codes/Android/Deadliner`

现有结构重点：

- `app/src/main/java/com/aritxonly/deadliner/data`
- `app/src/main/java/com/aritxonly/deadliner/model`
- `app/src/main/java/com/aritxonly/deadliner/ui/<feature>`
- `app/src/main/java/com/aritxonly/deadliner/capture/{data,model,ui}`

新增功能优先落位：

- 数据访问：`data`
- 领域/展示模型：`model`
- Compose 页面与状态：`ui/<feature>`
- 若功能复杂，可在 feature 下继续拆 `data / model / ui`

## 模块拆分建议

- `feature-contract`: DTO、路由参数、状态协议
- `feature-domain`: 规则、用例、聚合逻辑
- `feature-presentation`: 页面、组件、状态
- `feature-infra`: 仓储、数据库、网络、平台桥接

不是每个功能都要创建以上全部目录，但至少要先做逻辑拆分，再决定哪些模块可以合并。
