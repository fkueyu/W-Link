# W-Link Nightlight 单一编辑器与命令路径设计

## 目标

把独立“定时任务”页面和设备设置面板中的两套 Nightlight 控制合并为一个领域编辑器，并让所有 Nightlight 写入复用设备唯一会话的乐观更新、命令排序、权威响应、失败回滚和全局错误提示。

## 产品语义

WLED 当前能力是 Nightlight 倒计时，不是通用日程或自动化系统。用户入口和页面标题统一使用本地化 `nightlight` 文案；控制页状态副标题继续显示“定时进行中/未启用”。已有 `schedule` 文案保留给未来真正的日程能力，但本阶段不再把 Nightlight 页面展示为泛化“定时任务”。

独立页面是唯一完整编辑入口。设备设置面板只显示一个 Nightlight 摘要卡：图标、名称、当前启用状态和进入箭头；点击后打开同一个 Nightlight 页面。返回页面后仍可回到设备设置流程，不复制开关、滑块或模式选择器。

## 组件边界

新增 `NightlightEditor`，只接收当前 `WledNightlight`、本地化字符串和一个 `ValueChanged<WledNightlight>`。编辑器负责把开关、时长、目标亮度和模式操作转换成 `copyWith` 后的完整 Nightlight 值，不读取 API 或 Riverpod provider。

新增 `NightlightSummaryCard`，只负责展示摘要并触发 `onTap`。`DeviceSettingsSheet` 使用摘要卡；`NightlightScreen` 使用完整编辑器。这样领域 UI 可以在 widget test 中独立验证，页面只负责导航和状态绑定。

## 命令与数据流

`WledApiService.setNightlight` 接收完整 `WledNightlight`，但发送给 WLED 的 `nl` 对象只包含 `on`、`dur`、`mode` 和 `tbri`；设备只读的 `rem` 不回传。

`DeviceStateNotifier.updateNightlight(next)` 调用既有 `optimisticUpdate`：立即把 `state.nl` 替换为 `next`，再通过当前 session 的 API 提交；成功采用 WLED 返回的权威状态，失败恢复提交前快照并发布统一失败事件。多个快速操作继续受现有命令序号保护，旧响应不会覆盖新操作。

UI 不再调用 `refresh()`，因为成功响应已经是权威状态；也不直接持有 API。编辑器回调可以 fire-and-forget，因为 notifier 捕获异常并以 `DeviceCommandResult` 结束，不产生无人监听异常。

## 视觉与交互

保持现有极光玻璃、琥珀 Nightlight 图标和品牌紫选中态。开启时显示时长、目标亮度与四种模式；关闭时收起参数，减少设置面板噪音。模式名称全部来自本地化资源，移除中文界面中的硬编码“运行模式”“即时”和英文 `Instant`。

所有模式卡继续使用 `BouncyButton`，继承键盘和读屏能力；Switch 和 Slider 使用 Flutter 原生语义。该阶段不引入保存按钮、不新增通用日程、不修改 WLED Nightlight 数值范围。

## 错误与边界

- session/API 不可用时命令按既有失败契约回滚并显示全局错误提示。
- `duration` 保持 WLED 支持的 1–255 分钟，`targetBrightness` 保持 0–255，`mode` 保持 0–3。
- `rem` 只从设备响应读取，不参与用户提交。
- 设置面板的 Sync、Transition、设备信息和重启功能不受影响。

## 验证

- API 请求只发送四个可写 Nightlight 字段和 `v: true`，不发送 `rem`。
- notifier 在提交时立即更新 `nl`，成功采用权威响应，失败恢复原值并发布一次失败事件。
- 编辑器关闭状态不显示参数；开启、滑块和模式操作均产出正确的完整 `WledNightlight`。
- 摘要卡只显示状态和导航动作，不包含第二套 Switch/Slider/模式控件。
- 控制页与设置面板都打开同一个 `NightlightScreen`。
