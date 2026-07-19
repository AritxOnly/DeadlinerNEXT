#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from datetime import date
from pathlib import Path


def slugify(value: str) -> str:
    slug = value.strip().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    slug = re.sub(r"-{2,}", "-", slug).strip("-")
    if not slug:
        raise ValueError("feature slug must contain at least one ASCII letter or digit")
    return slug


def build_spec(title: str, feature: str) -> str:
    today = date.today().isoformat()
    return f"""# {title}

## 背景

- 创建日期：{today}
- 功能标识：`{feature}`
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
"""


def build_module_plan(title: str) -> str:
    return f"""# {title} Module Plan

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
"""


def build_tasks(title: str) -> str:
    return f"""# {title} Tasks

## 阶段 1：规格冻结

- [ ] 完成 `spec.md`
- [ ] 完成 `module-plan.md`
- [ ] 完成评审或自检

## 阶段 2：基础设施

- [ ] 确认共享依赖、接口、数据结构

## 阶段 3：功能实现

- [ ] 按模块分批实现
- [ ] 大型改动完成后再统一编译

## 阶段 4：验证与回写

- [ ] 执行规格校验
- [ ] 执行大文件扫描
- [ ] 回写最终实现状态
"""


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a Deadliner feature spec folder with standard SDD documents."
    )
    parser.add_argument("--feature", required=True, help="feature slug or raw name")
    parser.add_argument("--title", required=True, help="human-readable feature title")
    parser.add_argument("--root", default="specs", help="spec root directory")
    args = parser.parse_args()

    feature = slugify(args.feature)
    root = Path(args.root).resolve()
    target = root / feature

    if target.exists():
        raise FileExistsError(f"spec directory already exists: {target}")

    target.mkdir(parents=True, exist_ok=False)
    (target / "spec.md").write_text(build_spec(args.title, feature), encoding="utf-8")
    (target / "module-plan.md").write_text(build_module_plan(args.title), encoding="utf-8")
    (target / "tasks.md").write_text(build_tasks(args.title), encoding="utf-8")

    print(f"[OK] created {target}")
    print("[NEXT] fill spec.md before writing feature code")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
