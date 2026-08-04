# Lifi KMP Runtime Migration Tasks

## 阶段 1：规格冻结

- [x] 确认 KMP Core 已有 Lifi 编排、Memory 接口和 OHOS Ktor 客户端。
- [x] 确认当前鸿蒙入口仍指向 Rust `libffi_ohos.so`。
- [x] 定义单运行时、无 fallback 的迁移边界。

## 阶段 2：KMP bridge

- [x] 为 KMP AI config、输入、工具结果、事件和提取任务定义稳定 JSON C ABI。
- [x] 复用 iOS 已验证的 `KmpMemoryStoreAdapter`，消除 ArkTS/Rust memory snapshot 往返。
- [ ] 在 Core 端补充输入、工具续传、异常和 memory commit 的 OHOS bridge 自动化测试。

## 阶段 3：Harmony 接入

- [x] 在 NAPI 导出 Lifi bridge，并加入 ArkTS 类型声明。
- [x] 将 `DeadlinerCoreService` 改为唯一的 KMP client，保留 UI 进度与工具回调行为。
- [x] 将 `extractTasks` 改为 KMP bridge 实现。
- [x] 确认 AI 工具执行只经 KMP-backed Task/Habit repository。

## 阶段 4：同步、移除与验证

- [ ] 验证 AI 写入的 Memory/Profile 出现在 V3 changelog 并可 WebDAV 同步。
- [x] 构建 Release Core、替换 HAP 中的 `libDeadlinerCore.so`，构建 HAP。
- [ ] 设备验证：输入、工具续传、记忆、重启后数据、V3 WebDAV/iOS 联调。
- [x] 删除 `libffi_ohos.so` 及其 Rust FFI 构建/类型引用；确认签名 HAP 不再包含它。
- [x] 运行规格校验和核心文件大小检查，回写实际实现状态。

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
