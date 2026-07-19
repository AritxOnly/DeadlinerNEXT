# Immersive Material SDD Plan

本文用于规划 Deadliner 在 HarmonyOS API 26 上的沉浸光感改造，并作为后续实现的执行依据。

## 目标

- 统一 `.systemMaterial` 的接入方式，避免在业务组件里散落大量 `if/else`。
- 明确哪些组件由系统默认材质接管，哪些组件由应用主动配置沉浸材质。
- 为按钮、AI 输入栏、Popup、Toast 建立统一的材质接入层。
- 保持现有 API23/HDS 适配逻辑不被破坏，新增 API26 能力尽量收口在基础设施层。

## 非目标

- 本轮不改 `Segment` 的默认材质行为。
- 本轮不重构所有按钮组件层级，只提供可直接挂载的 modifier。
- 本轮不顺手调整现有业务文案、布局或交互流程。

## 设计原则

### 1. 系统默认优先

- `SegmentButton` 已自动接入 material，不再额外主动叠加沉浸材质。
- 只有当组件需要明确的交互反馈或视觉风格时，才由应用主动设置 `systemMaterial`。

### 2. 语义化 preset 优先

- 业务层不直接拼 `uiMaterial.ImmersiveMaterial` 参数。
- 业务层通过语义化 preset 获取 modifier，例如：
  - `surface`
  - `buttonInteractive`
  - `buttonGlow`

### 3. 运行时兼容优先

- 所有 API26 材质能力都必须经过统一的运行时可用性判断。
- 兼容逻辑集中在基础设施层，不散落在页面或组件中。

### 4. 批量替换优先

- 对高频通用能力（如 Toast），优先建立统一入口后再全量替换。
- 替换时只改调用入口，不混入业务逻辑重构。

## 范围拆分

## 阶段 1：基础设施

### 1.1 `SystemMaterialCompat`

新增或扩展：

- 统一的 API26 材质可用性判断
- 可复用的 `ImmersiveMaterial` builder
- 语义化 modifier preset

本阶段目标：

- 支持 `style`
- 支持 `interactive`
- 支持 `lightEffect`
- 为后续 Button / AI 输入栏 / Popup / Toast 提供统一接入面

### 1.2 `Toast.show()`

新增统一 Toast 入口：

- API：`Toast.show({ message, duration? })`
- 命名对齐 Android 使用习惯
- 在 API26 可用时自动附加沉浸材质

本阶段要求：

- 全仓替换现有 `promptAction.showToast(...)`
- 替换时不改原有文案与业务判断

## 阶段 2：AI 输入栏

目标：

- 复用并升级现有 `AITextInput`
- 接管 `AIPanelView` 底部的内联 `TextInput + Button`
- 输入主体接入沉浸材质
- 发送按钮接入 `interactive + lightEffect`

实施策略：

- 以现有 `AITextInput` 为基础演进
- 将其调整为适合 AI 页面底部输入栏的紧凑样式
- 再回接到 `AIPanelView`

## 阶段 3：Popup Surface

目标：

- 保持现有 `bindPopup(...)` 使用方式不变
- 用统一容器承接沉浸材质表现

实施策略：

- 新增 `ImmersivePopupSurface`
- 替换现有 popup builder 的根节点

首批落点：

- `OverviewPage`
- `TaskItemCard`
- `CaptureComponents`

## 阶段 4：Button 批量接入

目标：

- 为明确的交互型按钮提供统一沉浸材质 modifier

实施策略：

- 不额外包按钮组件
- 直接通过 modifier 挂载到现有 Button

优先级：

- 标题栏按钮
- AI 发送/触发按钮
- 灵感编辑页等独立交互按钮

## 组件策略

### Segment

- 保持现状
- 不主动补 `systemMaterial`

### Button

- 使用 modifier preset
- 推荐语义：
  - 普通前景按钮：`buttonInteractive`
  - 重点发光按钮：`buttonGlow`

### AI 输入栏

- 输入主体使用轻薄沉浸材质
- 发送按钮使用带互动反馈的沉浸材质

### Popup

- builder 根节点统一包裹 `ImmersivePopupSurface`

### Toast

- 统一走 `Toast.show()`
- API26 上自动附加沉浸材质

## 文件规划

### 新增

- `docs/immersive-material-sdd-plan.md`
- `entry/src/main/ets/common/ui/Toast.ets`

### 扩展

- `entry/src/main/ets/common/style/SystemMaterialCompat.ets`

### 后续阶段目标文件

- `entry/src/main/ets/pages/components/AITextInput.ets`
- `entry/src/main/ets/pages/common/AIPanelView.ets`
- `entry/src/main/ets/common/ui/ImmersivePopupSurface.ets`

## 风险与约束

- 当前工程兼容 SDK 仍低于 26，API26 能力会产生兼容性告警，因此运行时守护必须保留。
- `Toast.show()` 全量替换涉及文件较多，必须采用机械替换，避免混入额外逻辑改动。
- 沉浸材质的视觉层级较强，后续按钮和 popup 接入时需要逐页确认不会与现有背景模糊叠加过重。

## 当前执行顺序

1. 落地基础设施：`SystemMaterialCompat` preset 化。
2. 新增统一 `Toast.show()`。
3. 全仓替换 `promptAction.showToast(...)`。
4. 编译验证基础设施改造未引入新错误。
5. 再继续 AI 输入栏与 Popup Surface 改造。

## 当前进度（2026-07-05）

- 已完成阶段 1：
  - `SystemMaterialCompat` 已提供可复用 preset 与运行时守护
  - `Toast.show()` 已落地并完成全仓替换
- 已完成阶段 2：
  - `AITextInput` 已升级为共享输入组件，继续服务表单类多行 AI 输入场景
  - `AIPanelView` 已回退为页面内联 `TextInput + Button`
  - AI 页底部输入栏已直接在内联 `TextInput` / `Button` 上接入沉浸材质
  - AI 页高频动作按钮已接入 `buttonInteractive / buttonGlow`
- 已完成阶段 3：
  - 已新增 `ImmersivePopupSurface`
  - `OverviewPage` 的帮助类 popup 已切到统一沉浸材质 surface
  - `TaskItemCard` 备注 popup 已切到统一沉浸材质 surface
  - `CaptureComponents` 的手动整理 popup 已切到统一沉浸材质 surface
- 待进入阶段 4：
  - 继续筛选标题栏按钮与独立页面按钮，批量补齐沉浸材质 modifier
