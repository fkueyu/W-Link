# 跨功能重复报告

## 需要统一的重复

1. **同一设备的双实时会话**：detail 会话位于 `lib/providers/device_providers.dart:121-150`，family 会话位于 `:154-175`，宽屏同时挂载两者（`lib/screens/adaptive_shell.dart:46-74`），再以 `_syncToPeer` 桥接（`device_providers.dart:337-388`）。这是同一事实源的意外重复。
2. **设备选择所有权分散**：列表、宽屏壳和控制页分别写 current ID（`device_list_screen.dart:33-45`、`adaptive_shell.dart:24-30`、`device_control_screen.dart:41-49`）。导航形态可以特化，设备选择状态不应有三个写入者。
3. **状态提交有四种完成语义**：乐观更新（`device_providers.dart:337-365`）、Nightlight 写后立即读（`schedule_screen.dart:129-138`）、预设写后 invalidate（`presets_list_screen.dart:484-493`）、分段固定延迟强刷（`segments_list_screen.dart:477-496`）。同一 JSON 状态端点缺乏统一成功、失败、回滚和权威响应规则。
4. **主分段有三套解释**：`mainSeg`（`wled_state.dart:106-113`）、`seg.first`（`device_control_screen.dart:741-758`）、固定 ID 0（`wled_api_service.dart:107-168`）。这是会导致写错目标的意外重复。
5. **HTTP client 所有权分散**：detail/family provider 各持有一套（`device_providers.dart:121-175`），卡片每次操作又临时创建（`device_card.dart:342-355,456-473`）。分组 fan-out 的临时 client（`group_providers.dart:141-160`）属于合理特化。
6. **持久化接入分叉**：设备、设置、快捷色使用注入 prefs（`device_providers.dart:16-56`、`settings_provider.dart:14-69`、`quick_color_provider.dart:7-59`），分组自行取实例且写入不等待（`group_providers.dart:19-115`），收藏不发布状态（`favorites_service.dart:5-71`）。编码格式可以不同，生命周期与错误语义不应不同。
7. **Nightlight 两套完整实现**：独立页面（`schedule_screen.dart:75-301`）和设置面板（`device_settings_sheet.dart:82-123,403-448`）同时维护同一 `nl` 对象。
8. **效果与调色板页面镜像**：搜索、收藏、状态选择和提交几乎逐段重复（`effects_list_screen.dart:19-252`、`palettes_list_screen.dart:21-254`）。资源字段与翻译函数是参数差异，不是独立流程。
9. **页面 chrome 重复**：至少 8 个全屏页面复制背景、SafeArea、返回按钮与标题（如 `effects_list_screen.dart:37-69`、`settings_screen.dart:21-55`）；宽屏壳与设备列表又嵌套两层 AnimatedBackground（`adaptive_shell.dart:46-80`、`device_list_screen.dart:56-66`）。
10. **弹窗与 bottom sheet 外壳重复**：删除、重命名、保存、重置等重复构造玻璃容器与双按钮；例如 `device_card.dart:510-590`、`settings_screen.dart:515-595`、`presets_list_screen.dart:363-640`。

## 合理特化

- 自定义调色板使用 multipart `/upload`，与 JSON state 写入协议不同（`custom_palette_editor_screen.dart:552-589`）。
- 分组控制是一对多 fan-out，不能伪装成单一乐观状态（`group_providers.dart:141-190`）。
- 设备库额外同步 iOS App Group，因为存在原生消费者（`device_providers.dart:46-50`、`app_groups_service.dart:12-25`）。
- 实时灯光颜色与离线调色板色标使用不同选择器，副作用边界不同（`color_picker_sheet.dart:24-176`、`custom_palette_editor_screen.dart:469-549`）。
