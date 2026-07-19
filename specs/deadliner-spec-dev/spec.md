# Deadliner Spec Dev

## 背景

- 需要把 Deadliner 新功能开发的工程化约束沉淀成可复用 Skill，而不是每次临时口头说明。
- 当前 HarmonyOS 仓库已有 SDD 文档实践和大文件扫描脚本，但缺少统一入口。
- 三端代码风格与分层方式不同，需要一个统一的 Deadliner 交付协议来约束实现。

## 目标

- 建立一个可复用的 `deadliner-spec-dev` Skill。
- 强制采用文档优先的 SDD 流程。
- 为新功能提供统一的 `specs/<feature>/` 目录规范。
- 固化多模块拆分、1000 行文件治理、breaking change 守门和编译时机规则。

## 非目标

- 本轮不改造现有业务功能实现。
- 本轮不把 HarmonyOS 工程从单 HAP 构建模块重构为多个构建模块。
- 本轮不强制补齐历史功能的所有规格文档。

## 用户场景

1. 开发一个新功能时，先创建规格目录，明确目标、模块和任务，再开始编码。
2. 做跨端功能时，能够快速知道 iOS、HarmonyOS、Android 分别应落在哪一层。
3. 做大型改动时，能机械检查大文件风险与规格完整性，而不是靠记忆。

## 验收标准

- 仓库内存在 `skills/deadliner-spec-dev/`，包含 `SKILL.md`、参考文档、脚本和 `agents/openai.yaml`。
- 仓库内存在 `specs/deadliner-spec-dev/`，明确本 Skill 的需求、模块计划和任务拆分。
- 至少提供一个用于初始化规格目录的脚本，以及一个用于校验规格目录的脚本。
- Skill 文档明确要求：
  - 先文档后编码
  - 多模块拆分
  - 单个核心文件超过 1000 行前先申请逃逸
  - HarmonyOS `.ets` 修改时调用 arkts-* Skills
  - breaking change 前先做全工作区 commit
  - 大型改动完成后再统一编译，HarmonyOS 编译需指定 `DEVECO_HOME`

## 风险与约束

- 当前工作区存在大量未提交业务改动，本轮必须避免误碰无关文件。
- Skill 规范要足够具体，但不能长到难以触发和维护。
- 规格脚本只做轻量校验，不应阻塞开发者按实际情况调整实现。
