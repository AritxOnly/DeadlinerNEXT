---
name: deadliner-spec-dev
description: Use this skill when implementing a new Deadliner feature or a large feature refactor that must follow spec-driven development, multi-module decomposition, cross-platform style alignment, file-size guardrails, and delayed compile validation.
---

# Deadliner Spec Dev

## Overview

Use this skill to turn a Deadliner feature request into a spec-first delivery flow. It standardizes how to create `specs/` documents, split work into modules, align iOS/HarmonyOS/Android layering, and validate file-size and build guardrails before code is merged.

## When To Use

- A new Deadliner feature should be designed before coding.
- A feature touches multiple platforms and needs consistent module boundaries.
- The work may introduce large files, breaking changes, or build-risky refactors.
- You need a repeatable `specs/<feature>/` scaffold plus a validation checklist.

## Workflow

1. Start with docs, not code.
   Create or update `specs/<feature>/spec.md`, `module-plan.md`, and `tasks.md`.

2. Scaffold the spec folder when needed.
   Run:
   ```bash
   python3 skills/deadliner-spec-dev/scripts/init_feature_spec.py --feature <feature-slug> --title "<Feature Title>"
   ```

3. Read the right references before implementation.
   - `references/spec-template.md`: required document structure
   - `references/sdd-workflow.md`: end-to-end SDD workflow
   - `references/cross-platform-architecture.md`: platform layering and style alignment
   - `references/validation-playbook.md`: build, file-size, commit, and rollout guardrails

4. Split by modules before writing code.
   - Avoid single giant feature files.
   - For HarmonyOS, prefer simple layers such as `model`, `repository/service`, `page/component`.
   - For Android, prefer `data`, `model/domain`, `ui/<feature>`.
   - For iOS, align with `Core/Application/UseCases`, `Data`, and `Features/<Feature>`.

5. Enforce file-size guardrails.
   Run:
   ```bash
   python3 scripts/check_large_core_files.py --repo . --suffix-file core_suffixes.txt --threshold 1000
   ```
   If a core file must exceed 1000 effective code lines, stop and ask the developer for approval before continuing.

6. Load platform-specific skills when writing HarmonyOS code.
   - Any `.ets` edit: `arkts-grammar-standards`
   - ArkUI layout/state/UI work: `arkui-knowledge`
   - Build/type/lint failures: `arkts-error-fixes`
   - Runtime crash/white-screen/jscrash: `arkts-runtime-fix`

7. Guard risky delivery steps.
   - Before a breaking change, create one full-workspace Git commit.
   - Compile only after one substantial implementation batch, not after every tiny edit.
   - HarmonyOS compile commands must set `DEVECO_HOME` explicitly.

8. Validate the spec and close the loop.
   Run:
   ```bash
   python3 skills/deadliner-spec-dev/scripts/validate_feature_spec.py specs/<feature-slug>
   ```
   Then update the documents to reflect the implemented result, not just the planned result.

## Output Expectations

- The feature has a `specs/<feature>/` folder with complete docs.
- Module decomposition is explicit before coding starts.
- Large-file risk is checked mechanically, not by intuition.
- Cross-platform changes map back to each platform's established style.
- Validation notes record whether compile/build was run and why.
