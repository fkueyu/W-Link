# Device Session Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 W-Link 建立唯一的主分段语义、明确的 HTTP 失败契约，以及每台设备唯一且可回滚的状态会话。

**Architecture:** `deviceSessionProvider(deviceId)` 持有设备唯一的 API、WebSocket、轮询与状态；当前详情页只是该 family provider 的投影视图。命令仍兼容现有 `optimisticUpdate` 调用形态，但成功后采用设备返回状态，失败时回滚并发布可观察错误。

**Tech Stack:** Flutter、Dart、Riverpod 2、package:http、flutter_test

**Spec:** `PATHFINDER-2026-08-24/03-unified-proposal.md`

## Global Constraints

- 保留当前工作区中所有未提交改动，不清理、不覆盖无关文件。
- 本轮不提交 Git commit，避免把用户已有改动混入自动提交。
- 不保留 detail/family 两套网络会话，不通过 `_syncToPeer` 弥补重复状态源。
- 所有新增行为先写失败测试并确认失败，再写最小实现。
- UDP 保持实验性，不接入可靠状态控制链路。

---

### Task 1: 主分段模型语义

**Files:**
- Modify: `lib/models/wled_state.dart`
- Test: `test/models/wled_state_test.dart`

**Interfaces:**
- Produces: `WledSegment? get mainSegment`
- Produces: `WledState replaceSegmentById(WledSegment segment)`

- [x] **Step 1: 写失败测试**

```dart
test('mainSegment resolves by id instead of list position', () {
  final state = WledState(on: true, bri: 100, mainSeg: 7, seg: [
    const WledSegment(id: 2),
    const WledSegment(id: 7),
  ]);
  expect(state.mainSegment?.id, 7);
});

test('replaceSegmentById preserves order and replaces matching id', () {
  final state = WledState(on: true, bri: 100, seg: [
    const WledSegment(id: 2, bri: 10),
    const WledSegment(id: 7, bri: 20),
  ]);
  final updated = state.replaceSegmentById(const WledSegment(id: 7, bri: 99));
  expect(updated.seg.map((segment) => segment.id), [2, 7]);
  expect(updated.seg.last.bri, 99);
});
```

- [x] **Step 2: 运行测试并确认因 API 不存在而失败**

Run: `flutter test test/models/wled_state_test.dart`
Expected: FAIL，提示 `mainSegment` 或 `replaceSegmentById` 未定义。

- [x] **Step 3: 最小实现**

在 `WledState` 中按 `mainSeg` 查找真实 ID；找不到时回退第一个分段，空列表返回 null。替换操作只替换 ID 相同项，找不到时保持原状态。

- [x] **Step 4: 运行模型测试**

Run: `flutter test test/models/wled_state_test.dart`
Expected: PASS。

### Task 2: HTTP 明确失败契约

**Files:**
- Modify: `lib/services/wled_api_service.dart`
- Create: `test/services/wled_api_service_test.dart`

**Interfaces:**
- Produces: `WledApiException implements Exception`
- Changes: `setState(Map<String, dynamic>) -> Future<WledState>`，非 2xx、空响应或非法 JSON 均抛出异常。

- [x] **Step 1: 写失败测试**

用 `MockClient` 返回 500，断言 `setState` 抛出包含状态码和路径的 `WledApiException`；返回 200 的 WLED 状态 JSON 时，断言解析为真实 `WledState`。

- [x] **Step 2: 运行测试并确认 500 当前返回 null**

Run: `flutter test test/services/wled_api_service_test.dart`
Expected: FAIL，因为现有 `setState` 对 500 返回 null。

- [x] **Step 3: 最小实现**

为 `_get`、`_post` 增加统一 2xx 校验；`setState` 返回非空 `WledState`，解析错误包装为 `WledApiException` 并保留原因。

- [x] **Step 4: 运行服务测试**

Run: `flutter test test/services/wled_api_service_test.dart`
Expected: PASS。

### Task 3: 唯一设备会话与回滚

**Files:**
- Modify: `lib/providers/device_providers.dart`
- Modify: `lib/screens/device_control_screen.dart`
- Modify: `lib/screens/effects_list_screen.dart`
- Modify: `lib/screens/palettes_list_screen.dart`
- Modify: `lib/screens/presets_list_screen.dart`
- Modify: `lib/screens/schedule_screen.dart`
- Modify: `lib/screens/segments_list_screen.dart`
- Modify: `lib/widgets/device_settings_sheet.dart`
- Modify: `lib/widgets/device_card.dart`
- Create: `test/providers/device_state_notifier_test.dart`

**Interfaces:**
- Produces: `deviceSessionProvider(deviceId)`，每个 deviceId 唯一。
- Produces: `currentDeviceSessionNotifierProvider`，详情操作定位当前设备会话。
- Keeps: `deviceStateProvider` 作为当前详情状态的只读投影。
- Changes: `optimisticUpdate` 成功采用 API 返回状态，失败恢复 snapshot 并设置 `lastCommandError`。

- [x] **Step 1: 写失败测试**

创建可注入 fake API 的 notifier：初始状态亮度 10，乐观更新到 20；API 返回亮度 18 时最终为 18，API 抛错时最终回滚为 10 且 `lastCommandError` 非空。

- [x] **Step 2: 运行测试并确认当前实现不采用响应且不回滚**

Run: `flutter test test/providers/device_state_notifier_test.dart`
Expected: FAIL，最终状态仍为乐观值。

- [x] **Step 3: 合并 provider**

将原 family provider 重命名为 `deviceSessionProvider`；`deviceFamilyStateProvider` 仅作同一 provider 的兼容别名。详情状态通过当前 deviceId watch 同一个 family 实例，删除 detail 专用 API/WS 会话与 `_syncToPeer`。

- [x] **Step 4: 迁移详情操作入口**

将所有 `ref.read(deviceStateProvider.notifier)` 改为读取 `currentDeviceSessionNotifierProvider`；卡片继续读取同一个 family 实例。资源 providers 从当前会话复用 API。

- [x] **Step 5: 实现权威响应与失败回滚**

保存 snapshot；先发布乐观状态；API 成功返回状态后采用响应并保留已有 info（响应未携带 info 时）；异常时恢复 snapshot、记录错误并重新抛出，调用端可显示提示。

- [x] **Step 6: 运行 provider 测试与全量测试**

Run: `flutter test test/providers/device_state_notifier_test.dart`
Expected: PASS。

Run: `flutter test`
Expected: 全部 PASS。

### Task 4: 静态验证与变更文档

**Files:**
- Modify: `docs/深化改造说明.md`

**Interfaces:**
- Produces: 可追踪的第一阶段优化清单、验证结果和未完成项。

- [x] **Step 1: 分析与格式检查**

Run: `flutter analyze`
Expected: 0 errors。

Run: `dart format --output=none --set-exit-if-changed lib test`
Expected: exit 0。

- [x] **Step 2: 更新说明文档**

记录已完成的模型、通信与会话改造；明确颜色 latest-only 合并、完整视觉重构和真机通信验证仍属于后续阶段。

- [x] **Step 3: 检查工作区**

Run: `git diff --check && git status --short`
Expected: 无空白错误，且只包含原有改动与本阶段增量。
