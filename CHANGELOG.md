# Changelog

All notable changes to this project will be documented in this file.

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
