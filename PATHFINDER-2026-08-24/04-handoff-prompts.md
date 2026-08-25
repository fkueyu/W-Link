# 后续计划提示

```text
/make-plan 将 W-Link 的 detail/family 双会话统一为 deviceSessionProvider(deviceId)。单一入口必须拥有 HTTP、WebSocket、轮询、在线状态与资源释放；重写 device_providers.dart:111-404、device_card.dart:332-475、device_control_screen.dart:38-87。删除 _syncToPeer，不得保留两套路径或用 feature flag 并存。参考 PATHFINDER-2026-08-24/01-flowcharts/device-session-communication.md。
```

```text
/make-plan 为 W-Link 建立统一 DeviceCommand 提交语义：2xx 校验、typed error、请求序号、颜色 latest-only 合并、乐观 snapshot、成功采用权威响应、失败回滚与可见错误。迁移 Nightlight、预设、分段刷新和普通控制，禁止页面内固定延迟或 fire-and-refresh。参考 PATHFINDER-2026-08-24/01-flowcharts/lighting-capabilities.md。
```

```text
/make-plan 统一 W-Link 主分段语义。以 WledState.mainSeg 为唯一默认目标，提供 replaceSegmentById，迁移 device_control_screen、effects/palettes screens 与 wled_api_service 的固定 0/seg.first 调用。不得按列表位置推断 segment ID。
```

```text
/make-plan 精简 W-Link 交互壳：提取单一 NightlightEditor、共享效果/调色板选择壳、AppPageScaffold/AppDialog/AppBottomSheet，并消除宽屏重复背景。保持现有品牌 token 与设备色光场，不重做产品信息架构。
```
