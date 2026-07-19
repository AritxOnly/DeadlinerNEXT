# Validation Playbook

## 大文件治理

Deadliner 默认要求核心代码文件尽量不超过 1000 行有效代码。

检查命令：

```bash
python3 scripts/check_large_core_files.py --repo . --suffix-file core_suffixes.txt --threshold 1000
```

如果某个核心文件超过阈值：

1. 先拆职责，而不是直接接受大文件。
2. 若确实需要超过 1000 行，先向开发者申请“逃逸”。
3. 在规格文档里记录逃逸原因、影响范围和后续治理计划。

## Breaking Change 守门

- 在 breaking change 之前，先做一次全工作区 Git commit。
- 这次提交的作用是提供安全回退点，不代表功能已完成。
- 若当前工作区已很脏，先确认本轮改动边界，再谨慎提交。

## 编译策略

- 只在完成一次大型更改后统一编译。
- 不要求每个小 patch 都编译。
- 如果本轮只改文档、脚本、Skill，不强制做应用编译。

## HarmonyOS 编译要求

- 任何 HarmonyOS 编译命令都必须显式设置 `DEVECO_HOME`。
- 若使用 `hvigor` 或 `./gradlew` 包装命令，也要保证 `DEVECO_HOME` 已注入环境。

示例：

```bash
DEVECO_HOME=/path/to/deveco-studio python3 -c 'print("set before build")'
```

## 规格校验

校验 `specs/<feature>/` 目录：

```bash
python3 skills/deadliner-spec-dev/scripts/validate_feature_spec.py specs/<feature>
```

最少保证：

- `spec.md`
- `module-plan.md`
- `tasks.md`

## 回写要求

- 实现完以后，更新任务状态
- 如果模块拆分与最初不同，回写 `module-plan.md`
- 如果验收范围变化，回写 `spec.md`
