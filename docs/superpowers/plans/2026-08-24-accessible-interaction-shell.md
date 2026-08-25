# Accessible Interaction Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 W-Link 自定义弹性按钮补齐键盘、焦点与读屏支持，并确保宽屏双栏只绘制一层全局极光背景。

**Architecture:** `BouncyButton` 作为所有自定义可点击表面的统一交互边界，内部组合焦点、快捷键、语义和原有缩放动画。`AdaptiveShell` 在宽屏拥有全局背景，`DeviceListScreen` 根据既有嵌入状态选择透明内容或独立背景。

**Tech Stack:** Flutter、Dart、Material 3、flutter_test

**Spec:** `docs/superpowers/specs/2026-08-24-accessible-interaction-shell-design.md`

## Global Constraints

- 保留当前未提交改动，本轮不创建 commit。
- 保持现有 W-Link 极光玻璃视觉与按压缩放手感。
- Enter 与 Space 必须和指针点击调用同一个 `onTap`。
- 禁用按钮不得触发回调或触觉反馈。
- 宽屏只移除重复全局背景，不移除设备详情光场。
- 不修改 WLED 通信、会话和 Nightlight 业务。

---

### Task 1: 可访问弹性按钮

**Files:**
- Create: `test/widgets/bouncy_button_test.dart`
- Modify: `lib/widgets/bouncy_button.dart`

**Interfaces:**
- Changes: `BouncyButton` 新增 `semanticLabel`、`focusNode`、`autofocus` 参数。
- Preserves: `child`、`onTap`、`onLongPress`、`scaleTarget`、`duration`。

- [x] **Step 1: 写失败测试**：构建带 `semanticLabel: '打开设备'` 的按钮，断言语义节点具有按钮角色、启用状态和点击动作。
- [x] **Step 2: 运行 `flutter test test/widgets/bouncy_button_test.dart`**，确认因新参数不存在而失败。
- [x] **Step 3: 实现按钮语义和启用状态**：语义点击与手势点击共用 `_activate`，手势层排除重复语义。
- [x] **Step 4: 重跑按钮测试并确认第一组通过。**
- [x] **Step 5: 写失败测试**：通过 Tab 聚焦，分别发送 Enter 与 Space，断言回调累计两次且存在可见焦点环。
- [x] **Step 6: 运行定向测试并确认当前组件不响应键盘。**
- [x] **Step 7: 用 `FocusableActionDetector` 映射 `ActivateIntent`，在焦点高亮时绘制品牌紫边框。**
- [x] **Step 8: 写并运行禁用测试**：`onTap` 和 `onLongPress` 为空时，点击与 Enter 均不产生回调，语义为禁用。

### Task 2: 自适应背景单一所有权

**Files:**
- Modify: `test/screens/adaptive_shell_test.dart`
- Modify: `lib/screens/device_list_screen.dart`

**Interfaces:**
- Consumes: `DeviceListScreen._isEmbedded` 的既有 `onDeviceSelected != null` 判定。
- Produces: 宽屏嵌入列表不创建 `AnimatedBackground`，Scaffold 背景透明。

- [x] **Step 1: 写失败测试**：以 1000 像素宽构建 `AdaptiveShell`，断言 `AnimatedBackground` 数量为 1。
- [x] **Step 2: 运行 `flutter test test/screens/adaptive_shell_test.dart`**，确认当前双背景导致数量为 2。
- [x] **Step 3: 将设备列表内容提取为局部 Widget；独立模式包裹 `AnimatedBackground`，嵌入模式直接使用内容并设透明 Scaffold。**
- [x] **Step 4: 重跑 shell 测试，确认宽屏单背景和原有失败 Toast 均通过。**

### Task 3: 文档与完整验证

**Files:**
- Modify: `docs/深化改造说明.md`
- Modify: `docs/superpowers/plans/2026-08-24-accessible-interaction-shell.md`

**Interfaces:**
- Produces: 可核对的阶段三变更记录和验证结果。

- [x] **Step 1: 更新深化说明，记录按钮可访问性、背景所有权和本阶段非目标。**
- [x] **Step 2: 运行 `dart format lib test`、`flutter analyze`、`flutter test`。**
- [x] **Step 3: 运行 `git diff --check`，确认无空白错误且未覆盖无关改动。**
- [x] **Step 4: 请求独立代码审查，修复有效问题后重复全量验证。**

## Verification Result

- `dart format lib test`：78 个文件，无需修改。
- `flutter analyze`：0 个问题。
- `flutter test`：66 项全部通过。
- `git diff --check`：通过。
- 独立复审：0 个 Critical、0 个 Important，结论 Ready。
