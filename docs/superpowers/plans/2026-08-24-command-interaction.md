# Command Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为色盘增加 latest-only 串行发送，并为所有设备命令建立唯一的可见错误反馈出口。

**Architecture:** `LatestValueDispatcher<T>` 只负责合并异步值；设备权威状态仍由唯一 session 管理。失败由 session 发布全局带序号事件，`AdaptiveShell` 作为唯一 UI 监听者显示 Toast。

**Tech Stack:** Flutter、Dart、Riverpod、flutter_test

**Spec:** `docs/superpowers/specs/2026-08-24-command-interaction-design.md`

## Global Constraints

- 保留当前未提交改动，本轮不创建 commit。
- 色盘本地渲染不得等待网络。
- 同一调度器最多一个发送操作在执行，等待槽只保留最新值。
- 错误提示只有 AdaptiveShell 一个监听出口。
- 不启用 UDP，不自动重试命令。

---

### Task 1: Latest-only 调度器

**Files:**
- Create: `lib/core/latest_value_dispatcher.dart`
- Modify: `lib/core/core.dart`
- Create: `test/core/latest_value_dispatcher_test.dart`

**Interfaces:**
- Produces: `LatestValueDispatcher<T>(Future<void> Function(T) send)`
- Produces: `void submit(T value)`、`Future<void> get idle`、`void dispose()`

- [x] **Step 1: 写失败测试**：用 Completer 阻塞第一次发送，依次 submit 1、2、3，断言发送序列最终为 `[1, 3]`；空闲后 submit 4，断言立即开始。
- [x] **Step 2: 运行 `flutter test test/core/latest_value_dispatcher_test.dart`**，确认因类型不存在失败。
- [x] **Step 3: 实现单执行槽与单 latest 等待槽**；dispose 后忽略新值，但继续送达已排队的最终值。
- [x] **Step 4: 重跑调度器测试并确认通过。**

### Task 2: 色盘接入异步调度

**Files:**
- Modify: `lib/widgets/color_picker_sheet.dart`
- Modify: `lib/screens/device_control_screen.dart`
- Create: `test/widgets/color_picker_sheet_test.dart`

**Interfaces:**
- Changes: `ColorPickerSheet.onColorChanged` 为 `Future<void> Function(Color)`。
- Consumes: `LatestValueDispatcher<Color>`。

- [x] **Step 1: 写组件测试**：阻塞第一回调并连续触发三个颜色，断言本地选色更新而网络回调只收到首尾值。
- [x] **Step 2: 运行组件测试并确认当前同步回调实现失败。**
- [x] **Step 3: 在 State 中创建/释放 dispatcher，色盘和快捷色都调用 submit；控制页回调 await `optimisticUpdate`。**
- [x] **Step 4: 重跑组件测试并确认通过。**

### Task 3: 全局命令失败出口

**Files:**
- Modify: `lib/providers/device_providers.dart`
- Modify: `lib/screens/adaptive_shell.dart`
- Modify: `lib/core/l10n.dart`
- Modify: `test/providers/device_state_notifier_test.dart`
- Create: `test/screens/adaptive_shell_test.dart`

**Interfaces:**
- Produces: `DeviceCommandFailure(sequence, deviceId, error)`。
- Produces: `deviceCommandFailureProvider`。
- Produces: `AppStrings.controlFailed` 中英文文案。

- [x] **Step 1: 写 notifier 失败事件测试**：失败后断言事件序号、设备 ID 和错误，并确认只有一次状态变化。
- [x] **Step 2: 运行 provider 测试并确认 provider/type 不存在而失败。**
- [x] **Step 3: 在所有 optimisticUpdate 失败出口发布事件，成功不发布。**
- [x] **Step 4: 写 AdaptiveShell 组件测试，更新 failure provider 后断言出现本地化错误 Toast。**
- [x] **Step 5: 在 AdaptiveShell 添加唯一 ref.listen 并补齐中英文文案。**
- [x] **Step 6: 运行 provider 与 shell 测试并确认通过。**

### Task 4: 文档与全量验证

**Files:**
- Modify: `docs/深化改造说明.md`

- [x] **Step 1: 更新说明文档，记录 latest-only 和全局错误出口，不宣称真实设备验证。**
- [x] **Step 2: 运行 `dart format lib test`、`flutter analyze`、`flutter test`。**
- [x] **Step 3: 运行 `git diff --check` 并核对工作区。**
