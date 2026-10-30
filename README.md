# W-Link (幻彩) - Modern [WLED](https://kno.wled.ge/) Controller

**🇨🇳 中文 | [🇺🇸 English](README_EN.md)**

W-Link（幻彩）是一个现代化、极简设计的 [WLED](https://kno.wled.ge/) 设备控制应用，基于 Flutter 构建。它旨在提供流畅、直观的用户体验，让 [WLED](https://kno.wled.ge/) 灯带的管理变得简单而优雅。（注：该项目由 AI 协作完成，仅供学习参考）

🌐 **官网**: [https://ainx.ink/](https://ainx.ink/)
🍎 **iOS / iPadOS**: 已上架 App Store，请访问官网获取下载链接
🤖 **Android**: 请访问官网获取下载链接或在 GitHub Releases 中下载 APK
💻 **macOS / Windows**: 在 [GitHub Releases](https://github.com/fkueyu/W-Link/releases/latest) 下载通用 Mac ZIP 或 Windows x64 ZIP。Windows 请解压完整目录后运行 W-Link.exe；Mac 包目前未公证。

## ✨ 特性 (Features)

* **自动发现**: 通过 mDNS 自动发现局域网内的 [WLED](https://kno.wled.ge/) 设备，零配置上手。
* **实时控制**: HTTP + WebSocket 双轨混合通信，毫秒级响应开关、亮度、颜色和效果调节，支持多端状态实时同步。
* **乐观 UI (Optimistic UI)**: 操作即时反馈，无视网络延迟，提供丝般顺滑体验。
* **响应式布局**: 800px 断点自适应——iPhone 走 push 导航，iPad / macOS 走「设备列表 + 控制详情」双栏布局。
* **现代设计**: 玻璃拟态 (Glassmorphism) 视觉风格，配合 `flutter_animate` 带来的细腻微交互。
* **深色模式**: 完美适配 iOS / Android 系统级深色 / 浅色主题切换，OLED 友好的纯黑深夜主题。
* **Siri 快捷指令**: iOS 平台原生 App Intents 集成，可通过快捷指令 / Siri 直接控制设备。
* **防御性编程**: 针对网络波动优化的重试、降级与 WebSocket 指数退避重连，配合 HTTP 慢轮询兜底。

## 🛠 技术栈 (Tech Stack)

* **Framework**: Flutter 3.47.9（Dart 3.13.7），iOS / macOS 使用 Swift Package Manager
* **State Management**: [Riverpod 2.6](https://riverpod.dev/) （注解驱动 + 手写 StateNotifier 混合）
* **Networking**: `http` (Keep-Alive / 5 秒超时) + `web_socket_channel` (实时推送)
* **Discovery**: `multicast_dns` (mDNS 发现) + `connectivity_plus` (网络状态)
* **Storage**: `shared_preferences` （设备列表、偏好同步持久化）
* **UI Components**:
  * `flutter_animate`: 声明式动画
  * `flex_color_picker`: 专业色彩选择器
  * `cupertino_icons`: iOS 风格图标
* **Architecture**:
  * Feature-first 分层架构（`core` / `models` / `providers` / `services` / `screens` / `widgets`）
  * Code Generation (`riverpod_generator`, `json_serializable`)
* **Native iOS**: 已完全摆脱 CocoaPods，仅使用 Swift Package Manager；通过 `MethodChannel('flux/app_groups')` 与 App Group 共享设备列表给 App Intents。

## 📸 截图 (Screenshots)

| Light Mode                                 | Dark Mode                                |
| :----------------------------------------: | :--------------------------------------: |
| ![Light Mode](docs/screenshots/light.png)  | ![Dark Mode](docs/screenshots/dark.png)  |

## 🚀 快速开始 (Getting Started)

### 环境要求

* Flutter SDK 3.47.9 stable（内含 Dart 3.13.7，与 CI 保持一致）
* macOS 应用最低支持 macOS 12.0（新版 Flutter 要求）
* Xcode 16+（仅 iOS / macOS 构建）
* Android Studio / Android SDK（仅 Android 构建）

### 安装与运行

1. **克隆项目**

    ```bash
    git clone https://github.com/fkueyu/W-Link.git
    cd W-Link
    ```

2. **安装依赖**

    ```bash
    flutter pub get
    ```

3. **代码生成 (必须)**
    本项目使用 code generation 处理 JSON 序列化和 Riverpod providers。修改 model 或带 `@riverpod` 注解的文件后必跑。

    ```bash
    dart run build_runner build -d
    # 持续监听
    dart run build_runner watch -d
    ```

4. **运行**

    ```bash
    flutter run
    # 指定设备
    flutter run -d <device-id>
    ```

## 📂 项目结构 (Project Structure)

```text
lib/
├── core/          # 核心配置 (Theme, Constants, Extensions, l10n, Utils)
├── models/        # 数据模型 (WLED JSON API DTO) - 类型安全
├── providers/     # Riverpod Providers (业务状态层)
├── screens/       # 页面层 (含 adaptive_shell 响应式根布局)
├── services/      # 基础设施 (HTTP / WebSocket / mDNS / AppGroups / Storage)
├── widgets/       # 可复用组件 (GlassCard, BouncyButton, SmartSlider, ...)
└── main.dart      # 应用入口（注入同步 SharedPreferences）
```

## 📖 文档 (Docs)

`docs/` 下提供了完整的中文项目文档（不进入 App，但作为架构决策与发布说明的权威来源）：

* [`docs/架构设计.md`](docs/架构设计.md) — 设计原则、技术选型与分层依据
* [`docs/贡献指南.md`](docs/贡献指南.md) — 代码风格与 PR 规约
* [`docs/任务清单.md`](docs/任务清单.md) — 历史 roadmap 与已完成事项
* [`docs/帮助与支持.md`](docs/帮助与支持.md) — 终端用户 FAQ
* [`docs/应用商店元数据.md`](docs/应用商店元数据.md) — 上架文案
* [`docs/隐私政策.md`](docs/隐私政策.md) — 隐私政策正文

## 🤝 贡献 (Contributing)

欢迎提交 PR！请确保代码风格符合 `flutter_lints` 规范，并保持 "No Fluff" 的代码哲学。详见 [`docs/贡献指南.md`](docs/贡献指南.md)。

## 📄 许可证 (License)

本项目基于 MIT License 开源。

## ☕ 请我喝杯咖啡 (Support)

如果这个项目对你有帮助，欢迎请作者喝杯咖啡！

<p align="center">
  <img src="assets/donate/wechat.jpg" width="180" alt="微信赞赏码" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="assets/donate/alipay.jpg" width="180" alt="支付宝收款码" />
</p>

<p align="center">
  <sub>微信赞赏码 &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 支付宝收款码</sub>
</p>
