# 设计重做计划提示

```text
/make-plan Redesign W-Link. Current design failed audit at 13/30 with critical gaps in principles #3 aesthetic, #4 understandable, #5 unobtrusive, #6 honest, #7 long-lasting, #8 thorough, #9 environmentally friendly, and #10 as little design as possible.

Verdict paragraph:
> REDESIGN：13/30。保留 W-Link 的品牌色、设备色光场与“首页快速控制 → 详情精细控制”主路径，但需要重做状态所有权、信息层级和交互基础组件，而不是继续在现有重复结构上叠加样式。

Why redesign and not refine: 总分低于 20，且易理解、诚实、细致与克制等承重原则均只有 1 分；局部换皮不能解决双会话、错误语义和重复信息架构。

Preserve from current design:
- 品牌紫与深夜基础 token：lib/core/theme.dart:13-45。
- 设备当前颜色驱动的环境光：lib/widgets/device_ambient_background.dart:56-120。
- 首页快速控制、详情精细控制的两级任务路径：lib/widgets/device_card.dart:332-475；lib/screens/device_control_screen.dart:547-1079。

Discard:
- detail/family 两套会话及 _syncToPeer。Evidence: lib/providers/device_providers.dart:121-175,337-388。Caused failure on principles #2, #8, #9, #10.
- 页面各自拥有提交、sleep、refresh、catch 的写入策略。Evidence: lib/screens/schedule_screen.dart:129-243；lib/screens/segments_list_screen.dart:477-496。Caused failure on principles #4, #6, #8.
- Nightlight 双实现与重复页面 chrome。Evidence: lib/screens/schedule_screen.dart:75-301；lib/widgets/device_settings_sheet.dart:82-448。Caused failure on principles #5, #10.

Top moves:
1. #2 有用 / #8 细致：每台设备只保留一个实时 session，统一成功、失败、回滚、在线与刷新语义。Evidence: lib/providers/device_providers.dart:121-175,290-388.
2. #4 易理解 / #6 诚实：删除无行为的测试模式，把 Schedule 改名为“定时关闭与渐暗”，修正在线/局域网状态与文档夸大声明。Evidence: lib/screens/settings_screen.dart:106-123；lib/screens/schedule_screen.dart:64-243；README.md:14-18.
3. #10 尽可能少：合并 Nightlight 双实现、三处添加设备入口、重复页面/弹窗/sheet chrome。Evidence: lib/screens/schedule_screen.dart:75-301；lib/widgets/device_settings_sheet.dart:82-448；lib/screens/device_list_screen.dart:177-479.
4. #3 美观 / #7 持久：把 spacing 收敛到 6 档、type 收敛到 7 档、语义色集中到主题；保留设备色光场，减少其他霓虹渐变和玻璃层。Evidence: lib/core/theme.dart:13-96,183-276.
5. #5 不打扰 / #9 环保：停止不可见 ticker、消除宽屏重复背景与重复连接，并为高频颜色请求做 latest-only 合并。Evidence: lib/screens/adaptive_shell.dart:46-80；lib/widgets/device_ambient_background.dart:36-111；lib/widgets/color_picker_sheet.dart:194-236.

Redesign principles in priority order:
1. #2 Useful — 首屏和详情始终操作同一权威设备状态，失败可见且可恢复。
2. #4 Understandable — 标签准确描述 WLED 能力，主要操作无需理解协议缩写。
3. #10 As little design as possible — 一个任务一个入口，一个设备一个 session，一个 chrome 组件一个实现。

Deliverables:
- 新的信息架构，并明确首页、设备详情、灯带区域、定时关闭、设置的边界。
- 新主流程低保真图，与当前 flowchart 并排比较。
- empty/loading/error/success/focus/disabled 状态清单。
- 现有用户数据和快捷色/收藏/分组的迁移路径。
- 旧双会话、重复 Nightlight 和重复 chrome 的删除标准。

Anti-patterns:
- 不得仅在旧结构上换色或换圆角。
- 不得用 feature flag 长期保留双会话或新旧 UI。
- 不得为了跟随趋势增加更多玻璃、渐变或空闲动画。
- Preserve 列表中的品牌 token、设备色光场和两级控制路径必须保留。
```
