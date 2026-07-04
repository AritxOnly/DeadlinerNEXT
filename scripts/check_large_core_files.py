#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
from pathlib import Path


DEFAULT_EXCLUDE_DIRS = {
    ".git",
    ".idea",
    ".vscode",
    "node_modules",
    "dist",
    "build",
    "target",
    "out",
    "coverage",
    "__pycache__",
    ".next",
    ".nuxt",
    "vendor",
    "third_party",
    "Pods",
    ".gradle",
}


COMMENT_PREFIXES = {
    ".py": ["#"],
    ".sh": ["#"],
    ".yml": ["#"],
    ".yaml": ["#"],
    ".toml": ["#"],
    ".ini": ["#", ";"],

    ".js": ["//"],
    ".jsx": ["//"],
    ".ts": ["//"],
    ".tsx": ["//"],
    ".vue": ["//"],

    ".java": ["//"],
    ".kt": ["//"],
    ".go": ["//"],
    ".c": ["//"],
    ".cpp": ["//"],
    ".h": ["//"],
    ".hpp": ["//"],
    ".rs": ["//"],
    ".cs": ["//"],
    ".swift": ["//"],
}


def load_suffixes(suffix_file: Path) -> set[str]:
    if not suffix_file.exists():
        raise FileNotFoundError(f"后缀文件不存在: {suffix_file}")

    suffixes = set()

    with suffix_file.open("r", encoding="utf-8") as f:
        for line in f:
            raw = line.strip()

            if not raw:
                continue

            if raw.startswith("#"):
                continue

            if not raw.startswith("."):
                raw = "." + raw

            suffixes.add(raw.lower())

    if not suffixes:
        raise ValueError("后缀文件为空，或没有有效后缀")

    return suffixes


def is_excluded(path: Path, repo_root: Path, exclude_dirs: set[str]) -> bool:
    relative_parts = path.relative_to(repo_root).parts
    return any(part in exclude_dirs for part in relative_parts)


def count_code_lines(file_path: Path) -> int:
    suffix = file_path.suffix.lower()
    comment_prefixes = COMMENT_PREFIXES.get(suffix, [])

    code_lines = 0

    try:
        with file_path.open("r", encoding="utf-8", errors="ignore") as f:
            in_block_comment = False

            for line in f:
                stripped = line.strip()

                if not stripped:
                    continue

                # 粗略处理 C/Java/JS/Go/Rust 等块注释
                if in_block_comment:
                    if "*/" in stripped:
                        in_block_comment = False
                        after = stripped.split("*/", 1)[1].strip()
                        if after:
                            code_lines += 1
                    continue

                if stripped.startswith("/*"):
                    if "*/" not in stripped:
                        in_block_comment = True
                        continue

                    after = stripped.split("*/", 1)[1].strip()
                    if not after:
                        continue

                # 单行注释
                if any(stripped.startswith(prefix) for prefix in comment_prefixes):
                    continue

                code_lines += 1

    except OSError as e:
        print(f"[WARN] 无法读取文件: {file_path}，原因: {e}")

    return code_lines


def scan_repo(
    repo_root: Path,
    suffixes: set[str],
    threshold: int,
    exclude_dirs: set[str],
) -> list[tuple[Path, int]]:
    large_files = []

    for file_path in repo_root.rglob("*"):
        if not file_path.is_file():
            continue

        if is_excluded(file_path, repo_root, exclude_dirs):
            continue

        if file_path.suffix.lower() not in suffixes:
            continue

        code_lines = count_code_lines(file_path)

        if code_lines > threshold:
            large_files.append((file_path, code_lines))

    large_files.sort(key=lambda x: x[1], reverse=True)
    return large_files


def main():
    parser = argparse.ArgumentParser(
        description="扫描代码仓库，找出核心文件中代码行数超过阈值的文件。"
    )

    parser.add_argument(
        "--repo",
        type=str,
        default=".",
        help="代码仓库路径，默认当前目录",
    )

    parser.add_argument(
        "--suffix-file",
        type=str,
        default="core_suffixes.txt",
        help="核心文件后缀配置文件路径，默认 core_suffixes.txt",
    )

    parser.add_argument(
        "--threshold",
        type=int,
        default=1000,
        help="代码行数阈值，默认 1000",
    )

    parser.add_argument(
        "--exclude",
        type=str,
        nargs="*",
        default=[],
        help="额外排除的目录名，例如 --exclude generated mocks",
    )

    args = parser.parse_args()

    repo_root = Path(args.repo).resolve()
    suffix_file = Path(args.suffix_file).resolve()

    if not repo_root.exists():
        raise FileNotFoundError(f"仓库路径不存在: {repo_root}")

    if not repo_root.is_dir():
        raise NotADirectoryError(f"仓库路径不是目录: {repo_root}")

    suffixes = load_suffixes(suffix_file)
    exclude_dirs = DEFAULT_EXCLUDE_DIRS | set(args.exclude)

    large_files = scan_repo(
        repo_root=repo_root,
        suffixes=suffixes,
        threshold=args.threshold,
        exclude_dirs=exclude_dirs,
    )

    print()
    print("========== 核心大文件治理检查 ==========")
    print(f"仓库路径: {repo_root}")
    print(f"后缀文件: {suffix_file}")
    print(f"核心后缀: {', '.join(sorted(suffixes))}")
    print(f"阈值: {args.threshold} 行")
    print()

    if not large_files:
        print("未发现超过阈值的核心文件。")
        return

    print(f"发现 {len(large_files)} 个超过 {args.threshold} 行的核心文件，需要治理：")
    print()

    for file_path, line_count in large_files:
        rel_path = file_path.relative_to(repo_root)
        print(f"[治理提醒] {line_count:>5} 行  {rel_path}")

    print()
    print("建议治理方向：")
    print("- 拆分职责：将大文件按领域、模块、组件、工具函数拆分")
    print("- 降低耦合：检查是否存在过多跨模块依赖")
    print("- 抽离重复逻辑：把重复代码沉淀为公共函数或服务")
    print("- 补充测试：治理前后用单元测试或快照测试兜底")


if __name__ == "__main__":
    main()
