# Changelog

All notable changes to this project will be documented in this file.

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
