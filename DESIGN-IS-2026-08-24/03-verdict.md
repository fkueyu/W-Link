# 审计结论

**REDESIGN：13/30。保留 W-Link 的品牌色、设备色光场与“首页快速控制 → 详情精细控制”主路径，但需要重做状态所有权、信息层级和交互基础组件，而不是继续在现有重复结构上叠加样式。**

最高杠杆动作：

1. **#2 有用 / #8 细致**：每台设备只保留一个实时 session，统一成功、失败、回滚、在线与刷新语义。证据：`device_providers.dart:121-175,290-388`。
2. **#4 易理解 / #6 诚实**：删除无行为的测试模式，把 Schedule 改名为“定时关闭与渐暗”，修正在线/局域网状态与文档夸大声明。证据：`settings_screen.dart:106-123`、`schedule_screen.dart:64-243`、`README.md:14-18`。
3. **#10 尽可能少**：合并 Nightlight 双实现、三处添加设备入口、重复页面/弹窗/sheet chrome。证据：`schedule_screen.dart:75-301`、`device_settings_sheet.dart:82-448`、`device_list_screen.dart:177-479`。
4. **#3 美观 / #7 持久**：把 spacing 收敛到 6 档、type 收敛到 7 档、语义色集中到主题；保留设备色光场，减少其他霓虹渐变和玻璃层。证据：`theme.dart:13-96,183-276`、`01-evidence.md#视觉-token`。
5. **#5 不打扰 / #9 环保**：停止不可见 ticker、消除宽屏重复背景与重复连接，并为高频颜色请求做 latest-only 合并。证据：`adaptive_shell.dart:46-80`、`device_ambient_background.dart:36-111`、`color_picker_sheet.dart:194-236`。
