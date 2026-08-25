# Nightlight Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立唯一 Nightlight 编辑器和统一设备会话命令，删除设置面板中的重复控制与直接 API 刷新旁路。

**Architecture:** 纯 UI 的 `NightlightEditor` 产出完整领域值，`NightlightScreen` 将其交给 `DeviceStateNotifier.updateNightlight`。服务只序列化 WLED 可写字段；设置面板使用 `NightlightSummaryCard` 跳转同一页面。

**Tech Stack:** Flutter、Dart、Riverpod、Material 3、flutter_test、http MockClient

**Spec:** `docs/superpowers/specs/2026-08-24-nightlight-consolidation-design.md`

## Global Constraints

- 保留当前未提交改动，本轮不创建 commit。
- 用户界面称为“定时关闭与渐暗”/“Sleep Timer”，不暴露协议术语，也不称为通用日程自动化。
- 所有 Nightlight 写入必须经过设备唯一 session 的 `optimisticUpdate`。
- 成功采用 WLED 权威响应，失败回滚并复用全局错误提示。
- 请求不得发送只读 `rem` 字段。
- 不修改 WLED 的字段范围，不新增保存按钮或通用日程功能。

---

### Task 1: Nightlight 服务与会话命令

**Files:**
- Modify: `lib/services/wled_api_service.dart`
- Modify: `lib/providers/device_providers.dart`
- Modify: `test/services/wled_api_service_test.dart`
- Modify: `test/providers/device_state_notifier_test.dart`

**Interfaces:**
- Changes: `Future<WledState?> WledApiService.setNightlight(WledNightlight value)`。
- Produces: `Future<DeviceCommandResult> DeviceStateNotifier.updateNightlight(WledNightlight next)`。

- [x] **Step 1: 写 API 失败测试**：提交 `WledNightlight(on: true, dur: 45, mode: 2, tbri: 32, rem: 100)`，断言 POST body 的 `nl` 仅含 `on/dur/mode/tbri`，当前旧签名应导致编译失败。
- [x] **Step 2: 运行 `flutter test test/services/wled_api_service_test.dart`**，确认因新签名不存在失败。
- [x] **Step 3: 将 `setNightlight` 改为完整值序列化，继续委托 `setState` 获取权威响应。**
- [x] **Step 4: 重跑服务测试并确认通过。**
- [x] **Step 5: 写 notifier 失败测试**：调用 `updateNightlight(next)`，断言请求未完成时状态已经乐观更新，完成后采用权威 `nl`。
- [x] **Step 6: 运行 provider 测试，确认 `updateNightlight` 不存在而失败。**
- [x] **Step 7: 实现 `updateNightlight`，内部只调用 `optimisticUpdate` 和当前 `_api.setNightlight(next)`。**
- [x] **Step 8: 增加失败响应断言，确认恢复原 `nl` 且只发布一次 `DeviceCommandFailure`；重跑 provider 测试。**

### Task 2: 唯一领域编辑器与摘要卡

**Files:**
- Create: `lib/widgets/nightlight_editor.dart`
- Modify: `lib/widgets/widgets.dart`
- Create: `test/widgets/nightlight_editor_test.dart`

**Interfaces:**
- Produces: `NightlightEditor(value, strings, onChanged)`。
- Produces: `NightlightSummaryCard(value, strings, onTap)`。

- [x] **Step 1: 写编辑器失败测试**：关闭值只显示 Switch；点击开启后回调收到保留 dur/mode/tbri 且 `on: true` 的完整值。
- [x] **Step 2: 运行 `flutter test test/widgets/nightlight_editor_test.dart`**，确认组件不存在而失败。
- [x] **Step 3: 实现状态卡、开关和开启后的两个 SmartSlider，所有变更使用 `copyWith`。**
- [x] **Step 4: 写模式失败测试**：当前 mode 1 时点击本地化“日出模式”，回调收到 mode 3 且其余字段不变。
- [x] **Step 5: 实现四个本地化模式卡及描述，移除所有硬编码模式名称。**
- [x] **Step 6: 写摘要卡测试**：显示 Nightlight 名称和启用状态，点击只触发一次 onTap，树中没有 Switch/Slider。
- [x] **Step 7: 实现摘要卡并重跑全部 Nightlight widget 测试。**

### Task 3: 页面与设置面板迁移

**Files:**
- Create: `lib/screens/nightlight_screen.dart`
- Modify: `lib/screens/schedule_screen.dart`
- Modify: `lib/screens/screens.dart`
- Modify: `lib/screens/device_control_screen.dart`
- Modify: `lib/widgets/device_settings_sheet.dart`
- Modify: `test/widgets/nightlight_editor_test.dart`

**Interfaces:**
- Produces: `NightlightScreen`，观察 `deviceStateProvider` 并调用固定 session notifier。
- Changes: `DeviceSettingsSheet` 新增 `VoidCallback onOpenNightlight`。
- Preserves: deprecated `ScheduleScreen` 薄包装，避免外部引用立即断裂。

- [x] **Step 1: 创建 `NightlightScreen`，保留原页面头部、背景和提示卡，主体改为 `NightlightEditor`，回调只调用捕获的 session `updateNightlight`。**
- [x] **Step 2: 将 `schedule_screen.dart` 收敛为 deprecated 薄包装，并从 screens barrel 导出新页面。**
- [x] **Step 3: 控制页入口标题改为 `l10n.nightlight` 并打开 `NightlightScreen`。**
- [x] **Step 4: 设置面板删除 Nightlight Switch、Slider、模式选择器和直接 API/refresh 调用，改用 `NightlightSummaryCard`。**
- [x] **Step 5: 控制页创建设置面板时传入 `onOpenNightlight`，确保两个入口打开同一页面。**
- [x] **Step 6: 删除设置面板不再使用的 `_buildModePicker`，运行相关 widget 测试和静态分析。**

### Task 4: 通用设备会话竞态保护

**Files:**
- Modify: `lib/providers/device_providers.dart`
- Modify: `test/providers/device_state_notifier_test.dart`

- [x] **Step 1: 写失败测试**：复现命令期间旧 GET 回写、连续写请求并发、双失败回到临时快照三类竞态。
- [x] **Step 2: 给 GET 响应增加命令序列二次校验，命令开始后到达的旧响应直接丢弃。**
- [x] **Step 3: 为每个设备 session 增加串行写队列，同时保留即时乐观 UI。**
- [x] **Step 4: 以最后一次设备已确认状态为回滚基线，重跑 provider 定向测试。**

### Task 5: 文档、审查与全量验证

**Files:**
- Modify: `docs/深化改造说明.md`
- Modify: `docs/superpowers/plans/2026-08-24-nightlight-consolidation.md`

**Interfaces:**
- Produces: 第四阶段变更结构与可复核验证记录。

- [x] **Step 1: 更新总说明，记录唯一编辑器、统一命令、用户文案和删除的重复路径。**
- [x] **Step 2: 运行 `dart format lib test`、`flutter analyze`、`flutter test`。**
- [x] **Step 3: 运行 `git diff --check` 并检查计划无未完成项。**
- [x] **Step 4: 请求独立代码审查；修复 Critical/Important 后重新运行全量验证。**

**Final evidence:** 82 个 Dart 文件格式一致；`flutter analyze` 0 问题；`flutter test` 77/77 通过；`git diff --check` 通过；最终独立审查 Critical/Important/Minor 均为 0，结论 Ready。
