# Workspace Instructions

For HarmonyOS / ArkTS / ArkUI work in this repository, prefer the installed custom skills from the local Codex skill set before using generic reasoning.

Default skill routing for this workspace:

- Load `arkts-grammar-standards` before writing or modifying any `.ets` file.
- Also load `arkui-knowledge` when the task affects UI, layout, components, navigation, dialogs, rendering, or state-driven ArkUI behavior.
- Load `arkts-error-fixes` when build, compile, lint, or type-check output shows ArkTS errors or warnings that need fixing.
- Load `arkts-runtime-fix` when the app crashes, white-screens, exits unexpectedly, or when logs show jscrash, stack traces, or uncaught runtime exceptions.
- Load `deveco-create-project` for ArkTS project creation, initialization, or scaffolding tasks.

Workflow preference for ArkTS-related build and fix tasks:

- Use the skill-specific references and bundled scripts first when the selected skill provides them.
- Keep edits minimal and targeted to the reported ArkTS issue.
- Do not treat ArkTS as generic TypeScript; follow the ArkTS restrictions and ArkUI guardrails from the installed skills.
