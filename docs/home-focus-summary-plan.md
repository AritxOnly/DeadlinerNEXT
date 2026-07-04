# Home Focus Summary 方案

本文用于对齐 Deadliner 主页在 iOS 与 HarmonyOS 之间的首页摘要结构，并指导 HarmonyOS 第一轮实现。

## 目标

- 保留 HarmonyOS 现有的高辨识度元素：日期、年进度、下一项任务卡片。
- 修正 iOS 当前 Hero Summary 信息偏空的问题。
- 统一“主页摘要”与“概览页 Dashboard”的职责。

## 定位

- `Home / 主页`
  - 回答“现在该关注什么”
  - 以任务流和习惯流为主，摘要只负责聚焦与引导
- `Overview / 概览`
  - 回答“最近表现如何”
  - 承担完整统计、趋势、上月分析

主页不再承担完整 Dashboard 的职责，只承担 `Home Focus Summary`。

## 信息模型

主页摘要统一为一套 `HomeFocusSnapshot` 语义：

- 当前 segment 或当前整体状态
- 主值：待推进任务数 / 今日完成率
- 辅助说明：一句解释当前节奏
- progress：今日推进度
- metrics：2 到 3 个辅助指标
- next focus：下一项最值得打开的内容
- date：当前日期
- year progress：年度进度

## 组件拆分

### 1. Hero Summary

用于 `SM` 主界面顶部。

结构：

- `HeroSummaryCard`
- `Row { YearProgressCard, NextFocusCard }`

说明：

- 手机不采用 `Row { Hero + 右侧列 }`
- 原因是窄屏下 Hero 宽度会被压缩，信息主次不稳

### 2. Compact Focus Rail

用于 `MD / LG / XL` 的右侧摘要栏。

结构：

- `DateCard`
- `HeroCompactCard`
- `YearProgressCard`
- `NextFocusCard`

说明：

- `MD` 显示当前 segment 的摘要
- `LG / XL` 因为任务和习惯双列同时展示，右栏显示整体摘要

## 断点策略

### `SM`

- 在主列表顶部展示 Hero Summary
- 任务与习惯沿用原有切换逻辑

### `MD`

- 保留右侧栏
- 右侧栏改造成 segment-aware 的 `Compact Focus Rail`

### `LG / XL`

- 保留任务列 + 习惯列
- 不新增大 Hero
- 右侧栏显示整体摘要

## 指标口径

### Tasks

- 主值：未完成且未放弃的任务数
- metrics：
  - 逾期
  - 临期（24 小时内）
  - 今日完成
- progress：
  - `(今日完成任务) / (今日到期或已逾期任务 + 今日完成任务)`
- next focus：
  - 最近截止的未完成任务

### Habits

- 主值：今日完成率
- metrics：
  - 已打卡
  - 剩余
  - 已设提醒
- progress：
  - `(今日完成习惯) / (当前活跃习惯)`
- next focus：
  - 下一项未完成习惯
  - 优先有提醒时间的习惯

### All

用于 `LG / XL` 右侧栏。

- 主值：今日总推进度
- metrics：
  - 待推进任务
  - 已打卡习惯
  - 逾期任务
- next focus：
  - 优先展示下一项任务
  - 若无可推进任务，再展示下一项习惯

## 第一轮实现范围

- 新增统一组件：`HomeFocusPanel`
- 将 `MainHomePage` 的 `md / lg` 右栏切换到新组件
- 为任务列表、习惯列表增加头部插槽
- 在 `SM` 主界面顶部接入 Hero Summary

## 后续 iOS 对齐

- 将 iOS 现有 Hero Summary 调整为同一套字段
- 保留 Hero 的沉浸感，但补齐 Year Progress 与 Next Focus
- 让 iOS 与 HarmonyOS 共享同一套主页语义，不强制共享完全相同的布局
