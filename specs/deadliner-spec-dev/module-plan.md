# Deadliner Spec Dev Module Plan

## 模块拆分

- `skill-entry`
  - `skills/deadliner-spec-dev/SKILL.md`
  - 负责触发条件、主流程和必读参考入口

- `reference-rules`
  - `skills/deadliner-spec-dev/references/*.md`
  - 负责 SDD 流程、跨端分层、验证规则和规格模板

- `spec-tooling`
  - `skills/deadliner-spec-dev/scripts/*.py`
  - 负责规格目录初始化与静态校验

- `self-spec`
  - `specs/deadliner-spec-dev/*.md`
  - 负责把本 Skill 自己也纳入 SDD 管理

## 平台映射

- iOS
  - 参考 `~/Codes/iOS/Deadliner/Deadliner/Core`、`Data`、`Features`
  - 使用 DDD 分层，优先按 `Domain / Application / Data / Features` 落位

- HarmonyOS
  - 参考 `entry/src/main/ets/model`、`common/repository`、`pages/routes`
  - 使用简单分层，优先按 `model / service-repository / page-component` 落位

- Android
  - 参考 `~/Codes/Android/Deadliner/app/src/main/java/com/aritxonly/deadliner`
  - 使用简单分层，优先按 `data / model / ui` 落位

## 文件拆分策略

- Skill 主入口保持精简，只保留触发、顺序、命令和强规则。
- 细则放进 `references/`，避免 `SKILL.md` 膨胀。
- 脚本各自单责：
  - `init_feature_spec.py` 只负责建目录和模板
  - `validate_feature_spec.py` 只负责轻量结构校验
- 未来如果脚本继续扩展，单文件也要遵守 1000 行治理规则。

## 风险点

- `specs/` 模板过于刚性会降低实际可用性，因此只校验最小骨架。
- 当前 HarmonyOS 工程是单构建模块，规范里说的“多模块”必须解释为逻辑模块拆分，而不是强制立刻拆 HAP。
- 若未来要把 Skill 装到全局目录，需要再补安装说明或自动化，但不放在本轮范围内。
