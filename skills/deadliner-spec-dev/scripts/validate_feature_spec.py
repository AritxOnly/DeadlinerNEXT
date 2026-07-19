#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path


REQUIRED_FILES = {
    "spec.md": ["## 背景", "## 目标", "## 非目标", "## 用户场景", "## 验收标准", "## 风险与约束"],
    "module-plan.md": ["## 模块拆分", "## 平台映射", "## 文件拆分策略", "## 风险点"],
    "tasks.md": ["## 阶段 1：规格冻结", "## 阶段 2：基础设施", "## 阶段 3：功能实现", "## 阶段 4：验证与回写"],
}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate whether a Deadliner feature spec folder is complete."
    )
    parser.add_argument("spec_dir", help="path to specs/<feature>")
    args = parser.parse_args()

    spec_dir = Path(args.spec_dir).resolve()
    if not spec_dir.exists() or not spec_dir.is_dir():
        raise FileNotFoundError(f"spec directory not found: {spec_dir}")

    errors: list[str] = []

    for file_name, headings in REQUIRED_FILES.items():
        path = spec_dir / file_name
        if not path.exists():
            errors.append(f"missing file: {file_name}")
            continue

        content = path.read_text(encoding="utf-8")
        for heading in headings:
            if heading not in content:
                errors.append(f"{file_name} missing heading: {heading}")

    if errors:
        print("[FAIL] spec validation failed")
        for item in errors:
            print(f"- {item}")
        return 1

    print("[OK] spec validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
