# Changelog

All notable changes to this project will be documented in this file.

## [3.0.0] - 2026-10-30（构建 15）

### Added / 新增

- iPhone Duo 系统工具栏覆盖设备控制、发现、分组、设置及各二级页面；在具备原生能力时统一承载返回与操作，能力不可用时保留普通界面入口。
- 颜色选择支持 HEX 输入、键盘操作与快捷色持久化；大字号和窄屏下允许滚动操作。
- 设置页从当前安装包读取实际版本号，支持 iOS、Android 与 macOS。
- 增加 Windows 实际版本读取，并补齐 macOS 通用版、Windows x64 与 iPhone/iPad 归档的标签自动构建；全部验证成功后统一发布 Android 和桌面下载包。

### Fixed / 修复

- 修复折叠姿态和单双栏切换时的导航、选择状态、工具栏归属与失败回退，改善安全区与摄像头保留区避让。
- 修复设备发现的扫描超时、取消与迟到回调处理；单个服务解析失败不再中断其他设备发现。
- 修复网络连接状态在首次启动与回到前台时更新不及时，以及旧查询覆盖新状态的问题。
- 兼容部分 WLED 固件返回布尔型白光能力字段，避免设备信息解析失败。
- 修复预设、分段、定时渐暗及编辑弹层中的退出、输入和小尺寸布局问题。
- 补齐设备扫描失败提示的英文翻译。

### Optimized / 优化

- 首页与设备详情的灯光柔光收敛至卡片内部，减少屏幕和工具栏边缘的生硬截断。
- 调整提示留白、文字对比度、长标题、大字号布局与触控/读屏语义，保留现有操作反馈。
- 减少浅色、静态和不可见状态下不必要的动画工作。

### Platforms / 平台

- iOS / iPadOS：3.0.0 发布准备，重点完善 Duo 适配与通用交互。
- Android：包含通用发现、连接、固件兼容、界面和版本显示修复，发布3.0.0签名AAB/APK。
- macOS：固定兼容构建环境，保留原有部署目标与包标识，新增包含 Apple Silicon / Intel 的通用 ZIP；尚未配置 Developer ID 公证。
- Windows：新增包含完整运行文件的 x64 ZIP，统一 W-Link 窗口和可执行文件名称，保留已有存储身份。
- Linux：保留源码兼容；本次不新增安装包。

## [2.4.7] - 2026-10-24（构建 14）

### Added / 新增

- **折叠屏几何桥（`flux/duo`）**：Flutter 引擎在 iOS 上不提供折叠信息（`ViewConfiguration.displayFeatures` 官方文档写明只填充 Android），因此新增一个原生桥，从 UIKit 取两样引擎拿不到的东西——`UIHingeInteraction`（铰链状态与角度）与 `UIView.reservedRegions(of:)`（折叠分区、摄像头遮挡区），经 MethodChannel 送到 Dart。Dart 侧是 `DuoGeometryService` 与 `duoGeometryProvider`。
- **双栏在竖折时对齐折痕**：`AdaptiveShell` 拿到竖折分区后，左栏宽度取折痕坐标、右栏从折痕起，并且不再额外画一条分隔线——分隔线就是物理折痕。折痕位置落在 `[300, 0.55×宽]` 之外时退回固定 340（不硬套）。
- **半折/横折退回单栏**：铰链处于 `partiallyOpen` 或出现水平折痕时，横向双栏会把内容拦腰切断，此时走单栏布局。
- 新增 21 条判据：13 条载荷解析/退化路径、8 条布局（含「拿不到折叠信息时与改动前逐像素一致」这条回归守卫）。

### Notes / 说明

- **低于 iOS 27.1 时行为完全不变**：原生侧返回 `supported=false`，Dart 侧按「没有折叠信息」处理，所有 getter 为 null。iPhone 17（iOS 27.0）实测走的就是这条路径。
- **半折姿态未能取证**：`simctl` 没有折叠命令，DeviceHub 的设备窗口在当前环境里开不出来，所以折叠分区在真机上始终为空数组。竖折对齐与半折单栏只有用例断言，没有像素证据。详见[验证记录](docs/验证/2026-10-24-折叠几何桥/验证记录.md)。

## [2.4.6] - 2026-10-24（构建 13）

### Changed / 变更

- **动作入口归位到头部/详情列**：设备列表头部的「搜索」按钮改回它真正做的事——**添加设备**（图标 `+`、语义标签「添加设备」）。原来它是 `Icons.search` + `l10n.search`，点下去却进发现页，读屏用户会被念错。
- **移除底部浮动「添加设备」按钮**：加设备从此只有头部一个入口（空列表时另有 `EmptyState` 的主行动按钮）。双栏（iPad / 折叠内屏）模式下原先 `floatingActionButton` 被整条置空，**宽屏一个入口都没有**。
- **双栏详情列新增右上动作条**：补回嵌入模式丢掉的「设备设置」入口（玻璃条原写的是 `if (!widget.embedded)`，连唯一的 `tune` 入口一起跳过了）。
- 空列表提示文案随之更正（原文写「点击下方按钮或右下角」，那个位置已经没有任何按钮）。

### Notes / 说明

- 这一条只解决「动作可达且不重复」，**没有**实现 Duo 的竖排系统栏——Flutter 的 Material 条是自己的 `Positioned`，iOS 27.1 把系统条竖排的规则不作用于它。依据与取舍见[验证记录](docs/验证/2026-10-24-动作条归位/验证记录.md)。

## [2.4.5] - 2026-10-17（构建 12）

### Added / 新增

- **真机视觉验证工具**：`tool/shots/main.dart` 跑真正的 App，并从沙盒文件读指令注入指针事件（与真人点击同一条手势管线），配合 `xcrun simctl` 截图，可在无 GUI 模拟器、无屏幕录制权限的机器上取真机像素证据。用法与坑见[验证记录](docs/验证/2026-10-17-Duo%20视觉验证/验证记录.md)。
- **`GlassSheet` 弹层外壳**：底部弹层的玻璃底板统一为「模糊 30 + 0.85 填充 + 顶圆角」，不再允许只铺半透明色块。
- **折叠屏姿态判据**：新增 21 项测试，覆盖外屏（393×600、宽而矮的 480×600）、内屏（951×669）、半折（911×669）与分屏 50%（475×669）四种姿态，逐个断言无 `RenderFlex` 溢出；另含 3 条代码形状回归守卫（弹窗外壳、标题行可收缩、弹窗高度不得取整窗口高度）。

### Fixed / 修复

- **快速操作瓦片在中文两行标题下溢出（真机发现）**：固定 84pt 高度遇上「定时关闭与渐暗」折两行，真机 `BOTTOM OVERFLOWED BY 4.6 PIX`——而用例全绿，因为测试字体行高比 PingFang 小。高度改为按字号缩放（基础 92），标题硬上限两行并省略；旧用例里那条 `mainAxisExtent > 0` 的恒真断言已换成三条真判据。
- **色盘弹层缺背景模糊导致文字叠字（真机发现）**：弹层只有 65% 半透明填充、没有 `BackdropFilter`，背后页面的「颜色」「定时关闭与渐暗」原样透上来与「快捷色」叠在一起。改用 `GlassSheet`（与设备设置弹层同一套玻璃语言）。
- **折叠屏 / 小窗 / 键盘下的弹窗溢出（P0）**：8 处居中弹窗从「无高度上限、无滚动的 `Column`」改为统一外壳 `FluxDialogCard`（高度上限由当前约束推导 + 内容滚动 + 键盘上移），横屏、半折、分屏与键盘弹出时标题与按钮不再被裁掉。
- **色盘弹窗在宽而矮的外屏上溢出**：色盘边长改由可用高度预算推导（上限 320），不再只按宽度取正方形；快捷颜色在 480×600 下不再被挤出屏幕之外。
- **色盘弹窗文案行窄屏横向溢出**：393pt 宽度下「快捷颜色 / 长按保存」一行溢出 12px，已改为可收缩文案。
- **顶部玻璃条高度与内容偏移不一致**：两者改为由同一常量与 `padding.top` 推导，折叠屏保留区域变化时标题不再被玻璃条压住。
- **快速操作瓦片高度随宽度漂移**：由宽高比改为固定高度，窄屏不再被压扁、宽屏不再被拉高。
- **9 处手写标题行不可收缩**：统一为 `Expanded` + 单行省略号，侧栏与窄屏下长标题不再撑破整行。
- **底部弹层高度取整窗口高度**：分组「添加设备」弹层与设备设置弹层改为按实际约束推导，折叠/分屏/键盘下不再落到不可用区。

## [2.4.4] - 2026-08-25

### Added / 新增

- **设备光场**：控制页背景会跟随设备主色与开关状态变化，同时适配系统“减少动态效果”。
- **快捷色持久化**：支持长按覆盖快捷色，重新打开应用后仍会保留。
- **定时关闭与渐暗**：统一 Nightlight 编辑入口，支持时长、目标亮度和模式设置。
- **设备状态胶囊**：在“我的设备”标题右侧集中展示在线数、总数与局域网状态，并支持点击刷新。

### Optimized / 优化

- **设备会话架构**：同一设备的列表、详情和子页面复用唯一 HTTP、WebSocket 与轮询会话，减少重复连接和状态竞争。
- **通信可靠性**：写命令串行执行，丢弃过期响应；失败时恢复最后已确认状态，并统一展示可行动的错误提示。
- **高频调色**：色盘拖动期间合并中间请求，只发送当前在途值与最终颜色，降低 WLED 设备压力。
- **主分段一致性**：所有控制按 WLED 的真实 `mainseg` ID 读写，不再默认使用第一个分段。
- **首页体验**：状态胶囊与标题同行，下拉刷新等待真实设备响应，340px 紧凑布局与中英文长标题均可安全适配。
- **可访问性**：补充键盘操作、焦点反馈、读屏语义、禁用状态和分级触觉反馈。

### Fixed / 修复

- **状态竞争**：修复旧轮询或较慢命令响应覆盖用户最新操作的问题。
- **错误处理**：HTTP 非 2xx、非法响应和连接异常统一转换为明确错误，不再静默失败。
- **iOS 兼容性**：消除 `Locale.languageCode` 弃用警告，并让 Xcode 版本设置统一继承 Flutter 发布版本。

### Docs / 文档

- **AI 协作文档**：新增 `CLAUDE.md`，沉淀给 Claude Code 等 AI 工具的工程上下文，覆盖常用命令、Riverpod / JSON 双 codegen 流程、`adaptive_shell` 800px 双栏阈值、`MethodChannel('flux/app_groups')` 桥接、SwiftPM-only iOS 等读代码不易看出的事实。
- **中文文档落地**：将 `docs/` 下原英文文档替换为 6 份中文版本（架构设计、贡献指南、应用商店元数据、隐私政策、帮助与支持、任务清单），并在 `CLAUDE.md` 中索引每份文档的用途与适用场景。

## [2.4.3] - 2026-03-04

### Fixed / 修复

- **Preset Selection**: 修复选择预设后，切换效果、调色板、颜色或亮度时，预设选中状态不会自动清除的问题。
  - Fixed preset selection not clearing when changing effects, palettes, colors, or brightness.
- **Device Control (Android)**: 修复 Android 设备详情页无法控制开关的问题，将控制指令从 WebSocket 切换为更可靠的 HTTP API。
  - Fixed device control on Android detail page by switching control commands from WebSocket to reliable HTTP API.

### Optimized / 优化

- **Multi-Device Sync**: 增强多端状态同步，API 控制指令现在会强制要求 WLED 广播状态变化，确保多客户端实时同步。
  - Enhanced multi-device sync by forcing WLED to broadcast state changes, ensuring real-time synchronization across clients.
- **Connection Stability**: WebSocket 连接成功后保留慢速 HTTP 轮询（15 秒）作为兜底，防止 WebSocket 丢包导致状态不同步。
  - Added slow HTTP polling (15s) as fallback when WebSocket is connected, preventing sync loss from unreliable WebSocket.
- **Provider Stability**: 优化 Provider 依赖链，防止设备元数据更新（如 `lastSeen`）导致 WebSocket 和状态管理器不必要的重建。
  - Optimized provider dependency chain to prevent unnecessary rebuilds from metadata updates.

## [2.4.2] - 2026-03-04

### Fixed / 修复

- **Device Sync**: 彻底修复设备列表与详情卡片之间的状态同步问题，解除因实例变化导致的无限断线重连隐蔽 Bug。
- **Haptic Feedback**: 修复列表页与详情页中设备电源键由于重复响应事件而导致的两段式触觉反馈。

## [2.4.1] - 2026-03-04

### 优化

- **设备卡片**：优化设备列表卡片布局，卡片高度自适应内容，上下间距更对称协调。
- **亮度滑条**：增大亮度滑条高度，交互手感与视觉比例更佳。

## [2.4.0] - 2026-03-02

### Added / 新增

- **Per-Segment Configuration**: Support independent config of brightness, color, effect, and palette for each segment.
  - **分段独立配置**：支持对每个分段独立配置亮度、颜色、效果和调色板。
- **Smart Matrix**: Added 2D smart segment coordinate handling for Matrix devices.
  - **智能矩阵**：增强了对于矩阵设备的 2D 智能分段裁剪与合并能力。

### Optimized / 优化

- **Device Sync**: Reduced websocket race condition issues for smoother multi-parameter sliding.
  - **状态同步**：优化了 WebSocket 状态同步与乐观更新，滑动操作更丝滑无回弹。

## [2.3.1] - 2026-03-01

### Optimized / 优化

- **macOS**：macOS 桌面版优化，适配窗口大小与交互体验。
- **iPad**：优化 iPad 双栏布局与响应式适配。

## [2.3.0] - 2026-03-01

### Added / 新增

- **WebSocket**: 全面接入 WebSocket 实时通信，实现设备状态无延迟同步。
  - **WebSocket**：设备控制页及设备列表页全面接入 WebSocket，操作响应更快速，并且支持多端状态瞬间同步。

### Optimized / 优化

- **Connection Mechanism**: 增强连接机制，并支持 HTTP 无缝降级。
  - **连接机制**：增加 WebSocket 指数退避重连与 Ping 保活机制。当 WebSocket 不可用时，能够无缝、无感地降级恢复为 HTTP 轮询。
  - **iOS Build**: 修复并清理了 iOS 构建配置中 `sharedPreferencesProvider` 的命名冲突。

## [2.2.0] - 2026-02-02

### Optimized / 优化

- **Light Icons**: Refined light mode icons for better visual consistency.
  - **亮色图标优化**：优化了亮色模式下的图标视觉效果。
- **Device List**: Refined list page to prevent empty states when devices are offline.
  - **列表页重构**：优化并重构了列表页逻辑，避免设备离线时显示空白。
- **Control Screen**: Fine-tuned details on the device control screen for a better user experience.
  - **设备详情页优化**：对设备详情页进行了多项交互细节优化。

### Added / 新增

- **Custom Alias**: Users can now set custom names (remarks) for their WLED devices.
  - **设备备注支持**：现在支持为 WLED 设备修改并保存备注名称。

## [2.1.1] - 2026-02-01

### Optimized / 优化

- **UI Details**: Refined UI elements for better aesthetic consistency.
  - **UI 细节优化**：优化了各处 UI 细节，提升视觉一致性。

### Fixed / 修复

- **Known Issues**: Fixed several identified bugs to improve stability.
  - **修复已知问题**：修复了若干已知 Bug，提升应用稳定性.

## [2.1.0] - 2026-01-29

### Optimized / 优化

- **UI Details**: Refined UI elements for better aesthetic consistency.
  - **UI 细节优化**：优化了各处 UI 细节，提升视觉一致性。

### Fixed / 修复

- **Known Issues**: Fixed several identified bugs to improve stability.
  - **修复已知问题**：修复了若干已知 Bug，提升应用稳定性.

## [2.0.3] - 2026-01-29

### Fixed / 修复

- **App Icons (iOS)**: Removed alpha channel from iOS icons to comply with App Store submission requirements.
  - **应用图标 (iOS)**：排除了 iOS 图标的 alpha 透明通道，满足 App Store 上架合规性。
- **Missing Icons**: Supplemented missing icon sizes (@1x) for iPad and iPhone to eliminate Xcode warnings.
  - **图标缺失**：补全了 iPad 和 iPhone 缺失的各尺寸图标 (@1x)，消除 Xcode 警告。
- **Android Icons**: Synchronized all Android icon assets (Legacy, Night, Adaptive) with the new branding.
  - **Android 图标**：同步更新了 Android 全套图标（包括常规、深色模式及自适应图标）。

### Optimized / 优化

- **Architectural**: Migrated to modern iOS `UIScene` lifecycle for better system compatibility.
  - **架构改进**：迁移至现代 iOS `UIScene` 生命周期，适配最新系统规范并消除警告。
- **Bonjour Discovery**: Enhanced native discovery logic for more robust local network device resolution.
  - **设备发现**：优化了原生 Bonjour 解析逻辑，提升局域网设备发现速度与稳定性。

## [2.0.2] - 2026-01-29

### Optimized / 优化

- **Localization**: Fixed Chinese/English translation issues in the Schedule (Timer) screen.
  - **本地化**：修复了定时任务页面中的中英文翻译问题。
- **UI Text**: Unified terminology for Timer Modes and Status indicators.
  - **UI 文本**：统一了定时模式和状态指示器的术语。

## [2.0.1] - 2026-01-29

### Optimized / 优化

- **Dark Mode**: Complete overhaul of the Dark Mode aesthetic to a "Deep Night" theme.
  - **暗色模式**：将暗色模式彻底重构为“深夜”主题。
  - Replaced background with Pure Black (#000000) for OLED optimization. (背景替换为纯黑以优化 OLED 显示)
  - Updated surface colors to iOS-standard Dark Gray (#1C1C1E). (表面颜色更新为 iOS 标准深灰)
  - Refined Glassmorphism effects for better contrast and readability. (优化玻璃拟态效果提升可读性)
- **UI Components**: Improved visibility of sliders, headers, and dialogs in dark environments.
  - **UI 组件**：提升了滑块、标题和对话框在暗色环境下的可见性。

## [2.0.0] - 2026-01-29

### Added / 新增

- **Major Release**: Milestone version for W-Link 2.0.
  - **重大更新**：W-Link 2.0 里程碑版本。
- **Performance**: Improved device discovery and connection stability.
  - **性能优化**：改进了设备发现和连接稳定性.
- **UI/UX**: Foundation for the new Glassmorphic design language.
  - **UI/UX**：确立了全新的玻璃拟态设计语言。
