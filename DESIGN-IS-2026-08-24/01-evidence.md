# W-Link 设计审计证据

所有视觉结论均为源码推断，未使用运行时截图。

## 结构

- 静态交互声明 103 个；主要界面 88 个、通用组件 15 个。代表证据：`device_list_screen.dart:66-419`、`device_control_screen.dart:122-1069`、`groups_management_screen.dart:31-988`。
- 最大组件树深度 16 层，位于 `DeviceCard.build()` 的 `RepaintBoundary → … → Text`（`device_card.dart:58-163`）。
- 同目的额外 affordance 8 个：添加设备额外 2 个，卡片/详情电源和亮度各 1 个，Nightlight 四类控制各重复 1 个。
- dead prop 1 个：`DeviceListScreen.selectedDeviceId` 被传入但未读取（`device_list_screen.dart:22-27`、`adaptive_shell.dart:54-57`）。unused import 0。

## 视觉 token

- spacing 字面尺度 20 档：`[0,2,4,6,7,8,10,12,14,16,18,20,24,28,32,40,48,80,100,120]`。代表证据：`device_control_screen.dart:135-520`、`device_discovery_screen.dart:196,294`。
- type 字面尺度 13 档：`[11,12,13,14,15,16,17,18,19,20,22,24,32]`。主题仅定义 12/14/16/20/24/32，但页面继续增加 11/13/15/17/18/19/22（`theme.dart:183-211`、`device_card.dart:134,191`、`device_list_screen.dart:322`）。
- 基础颜色引用 67 个：35 个 ARGB 字面量 + 32 个 Material named colors。主题来源 `theme.dart:13-67`，局部页面色见 `device_control_screen.dart:109-710`、`groups_management_screen.dart:68-495`。
- 主文本对比度良好：亮色 13.04:1、暗色 20.72:1（`theme.dart:33-45,183-211`）。但次要文本多处失败：light bodyMedium 4.24:1、bodySmall 3.00:1、品牌紫对白 4.06:1、white38 对暗 surface 3.57:1、black38 对白 2.68:1、orange 对白 2.16:1（使用点见 `device_list_screen.dart:157-168,337-359`、`device_control_screen.dart:136-141,933-1045`）。
- 状态：empty/loading/error/success/disabled 存在；显式 focus 状态缺失。证据：`device_list_screen.dart:369-387`、`device_control_screen.dart:74-78,179-225,554-684`；全仓无 `WidgetState.focused`/`FocusTraversalOrder`。

## 文案与诚实性

- l10n 有 174 个语义 key、348 条中英文实现；界面引用 128 个，46 个未引用（`l10n.dart:6-960`）。screens/widgets 另有 93 处硬编码用户文案，集中在 groups 25、segments 24、presets 18。
- 多处声明没有测量支撑：“毫秒级响应/零延迟/无视网络延迟”（`README.md:14-15`）与 5 秒 HTTP timeout、失败不回滚冲突（`wled_api_service.dart:13-17`、`device_providers.dart:337-365`）。
- “纯黑主题”与 `#020205/#161621` token 不符（`README.md:18`、`theme.dart:29-36`）；“后台立即挂起、几乎不耗电”没有生命周期代码支撑（`docs/帮助与支持.md:17-18`、`device_providers.dart:111-275`）。
- label→behavior mismatch：测试模式空实现（`settings_screen.dart:106-123`）；“定时任务/自动化”实际仅 Nightlight（`schedule_screen.dart:64-243`）；“局域网可用”桌面端恒 true（`connectivity_provider.dart:9-14`）；“在线设备数”没有离线写入路径（`device_providers.dart:290-307`）。
- 未发现强制续用、隐藏费用、虚假稀缺、confirmshaming 等 dark pattern。

## 重量与摩擦

- Initial JS：N/A，原生 Flutter 应用。
- 首页网络操作为 `2 × V`（V 为首批构建的设备卡数）：每卡一次 `/json` 和一次 WS 握手（`device_card.dart:43-46`、`device_providers.dart:154-260`）。
- 控制页新增 6 个网络操作：状态 GET + WS + effects/palettes/presets/fxdata 四个 GET（`device_providers.dart:219-291,410-435`）。
- Home TTI 只能估算为 SharedPreferences 初始化 + 首帧；控制页 `TTI ≈ /json RTT + 一帧`。离线时第三次 5 秒失败后才出错，情景上限约 15 秒（`device_providers.dart:188-190,290-306`）。
- 首页和控制页各有一个重复 ticker；减少动态效果时停止，但亮色首页/关灯控制页仍可能运行不可见 ticker（`animated_background.dart:57-100`、`device_ambient_background.dart:36-111`）。
- debug APK 159,852,822 bytes（152.45 MiB），不能代表 release/AAB；release size 未测。
- 首屏自动通知、Badge、Modal 均为 0。

## 无障碍

- 显式 `Semantics` 仅 3 个：设备概览 1、控制页电源与亮度 2（`device_overview_bar.dart:24-29`、`device_control_screen.dart:554-676`）。
- `BouncyButton` 使用 GestureDetector 的 down/up/cancel，没有 Focus、Actions、Shortcuts 或常规 `onTap`（`bouncy_button.dart:53-80`）。因此返回、添加、设备卡、电源、颜色、效果、预设、分段和设置等主要操作没有静态键盘可达证据。
- 首页实际键盘顺序主要为更多菜单和各设备亮度 Slider；控制页主要为亮度与效果参数 Slider。见 `device_list_screen.dart:197-242`、`device_card.dart:441-475`、`device_control_screen.dart:663-1075`。
- Flutter landmark-like 显式区域 0；skip-link 对原生应用 N/A，等效焦点分组/跳主内容动作缺失。
