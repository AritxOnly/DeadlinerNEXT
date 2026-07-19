# Deadliner Spec Dev Tasks

## 阶段 1：规格冻结

- [x] 明确 Skill 目标、非目标和验收标准
- [x] 明确 Skill 自身模块拆分
- [x] 明确跨端分层、1000 行治理和编译约束

## 阶段 2：基础设施

- [x] 初始化 `skills/deadliner-spec-dev/` 目录
- [x] 补齐 `agents/openai.yaml`
- [x] 设计 `specs/<feature>/` 标准骨架

## 阶段 3：功能实现

- [x] 编写 Skill 主入口
- [x] 编写 SDD / 架构 / 验证参考文档
- [x] 实现规格初始化脚本
- [x] 实现规格校验脚本

## 阶段 4：验证与回写

- [x] 运行 Skill 结构校验
- [x] 运行规格目录校验
- [x] 记录是否需要应用编译，以及原因

验证备注：

- `specs/deadliner-spec-dev/` 已通过 `validate_feature_spec.py`
- `init_feature_spec.py` 已在 `/private/tmp/deadliner-spec-dev-e2e/demo-spec-skill` 完成真实脚手架演练
- 通用 `quick_validate.py` 依赖 `PyYAML`，当前环境缺少该依赖，因此本轮改用无依赖 frontmatter 自检
- 本轮只新增 Skill、文档和 Python 脚本，没有修改 HarmonyOS 应用业务代码，因此未执行应用编译
