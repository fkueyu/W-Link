# W-Link 高频命令与错误反馈设计

## 目标

保持色盘手感即时，同时避免拖动期间为每个触点创建 HTTP 请求；任何设备命令失败都只在应用壳显示一次明确提示。

## 命令合并

新增通用 `LatestValueDispatcher<T>`。首次值立即发送；发送进行中提交的新值覆盖待发送槽位；当前请求结束后只发送最后一个待处理值。调度器不负责业务状态和重试，设备状态仍由 `DeviceStateNotifier.optimisticUpdate` 的权威响应、回滚和序号保护负责。

调度器捕获异步发送异常，记录 `lastError` 并通过可选 `onError` 上报，然后继续处理等待中的最终值，不产生无人监听的 Future 异常。

`ColorPickerSheet` 继续逐次更新 `_currentColor`，因此拇指移动不受网络影响；传给控制页的异步回调通过调度器串行执行。关闭面板后停止接收新值，但仍送达已经排队的最终颜色，不中断已经发出的 HTTP 请求，也不吞掉用户最后一次选择。

打开色盘时捕获固定的目标 session 和 API；之后即使宽屏切换当前设备，排队颜色仍只作用于原设备。若原 session 已释放，命令安全返回 failure，不访问失效的 Riverpod ref。

## 错误反馈

新增全局 `deviceCommandFailureProvider`，失败事件包含递增序号、设备 ID 和原始错误。`DeviceStateNotifier` 在无法提交或 API 失败时发布事件，同时保留 `DeviceCommandResult.failure` 供需要定制处理的调用端使用。

`AdaptiveShell` 是唯一错误反馈监听者，以本地化通用文案调用 `AppToast.error`。底层服务不拼接用户文案，宽屏模式也不会因列表和详情同时挂载而重复提示。

## 非目标

- 不接入 UDP Realtime。
- 不自动重试控制命令，避免重复执行结构性操作。
- 不在本阶段重做 Toast 视觉、Nightlight 或页面信息架构。

## 验证

- 调度器在首请求阻塞时连续收到三个值，只发送第一个和最后一个。
- 请求空闲时新值立即发送。
- notifier 失败会回滚并发布一次带设备 ID 的事件。
- 自适应壳收到事件后显示本地化错误提示。
