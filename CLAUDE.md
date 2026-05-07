# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Identity

- 显示名 **W-Link**（幻彩），但 `pubspec.yaml` 的包名是 `flux`，主题/根组件等内部标识也使用 `Flux*` 前缀（`FluxApp`、`FluxTheme`）。修改命名时需同时考虑这两套名字，避免误改对外品牌名。
- 这是一个 Flutter 客户端，通过局域网 HTTP/WebSocket 控制 [WLED](https://kno.wled.ge/) 灯带设备；目标平台主要是 iOS / Android（macOS、Linux、Windows、web 目录存在但非主战场）。

## Common Commands

```bash
# 安装依赖
flutter pub get

# 代码生成（必须 —— 修改 model 或 *Provider 注解后必跑）
dart run build_runner build -d
# 持续监听重生成
dart run build_runner watch -d

# 静态分析（CI 必跑）
flutter analyze

# 全部测试
flutter test
# 单测（注意路径）
flutter test test/widget_test.dart
flutter test test/models/<file>_test.dart

# 运行（默认设备）
flutter run
flutter run -d <device-id>

# 应用图标（修改 flutter_launcher_icons.yaml 后）
dart run flutter_launcher_icons
```

CI（`.github/workflows/flutter_ci.yml`）只跑 `flutter pub get`、`flutter analyze`、`flutter test`，iOS 构建在 CI 中是注释掉的。

## Code Generation 注意事项

- 同时使用 `riverpod_generator` 和 `json_serializable`，所有 `*.g.dart` 与源文件并排生成，**不要手改 `.g.dart`**。
- 当前生成产物覆盖 `lib/models/` 下的 WLED DTO（`wled_info.g.dart`、`wled_segment.g.dart`、`wled_state.g.dart`）。新增带 `@riverpod`、`@JsonSerializable` 的文件后必须重新跑 `build_runner`。
- 部分 provider（如 `lib/providers/device_providers.dart` 内的 `DeviceListNotifier`）仍是手写 `StateNotifierProvider`，与注解生成 provider 混用，不必强制统一。

## High-Level Architecture

应用是 feature-first + 分层结构，状态管理统一走 Riverpod 2.6。

### 启动入口

`lib/main.dart` 在 `runApp` 之前 `await SharedPreferences.getInstance()` 并通过 `ProviderScope.overrides` 注入 `sharedPreferencesProvider`；所有依赖 prefs 的 provider 都从该 override 拿同步实例，避免初始化期出现 `AsyncValue`。`FluxApp` 监听 `settingsProvider` 切换主题与 locale。

### 自适应布局壳

`lib/screens/adaptive_shell.dart` 是布局根：以 `800px` 为阈值，宽屏（iPad 横屏 / macOS）走「左侧设备列表 + 右侧控制页」双栏；窄屏（iPhone）回退到 push 导航。新增主页面时考虑两种布局形态。

### 分层目录

- `lib/core/` — 跨层基础设施：`theme.dart`（玻璃拟态 token）、`constants.dart`（端口、超时、防抖间隔、亮度范围等 WLED 协议常量）、`extensions.dart`（`Color ↔ WLED [r,g,b,w]` 互转）、`l10n.dart`、`effect_translations.dart`、`wled_metadata_helper.dart`、`platform_utils.dart`。
- `lib/models/` — WLED JSON API 的强类型 DTO，是协议层。修改字段后会破坏 `.g.dart`，必须重新生成。
- `lib/providers/` — 业务状态层；通过 `providers.dart` 桶式 export。`common_providers.dart` 暴露 `sharedPreferencesProvider`、`currentDeviceIdProvider` 等横切 provider，screens 之间通过 provider 而非构造参数传递选中设备。
- `lib/services/` — IO 与基础设施：
  - `wled_api_service.dart` — HTTP，5 秒超时、Keep-Alive，针对 WLED `/json`、`/json/state`、`/json/info`、`/json/eff` 端点。
  - `wled_websocket_service.dart` — 实时状态推送。
  - `mdns_discovery_service.dart` — 局域网 mDNS 自动发现。
  - `app_groups_service.dart` — iOS-only 桥接，通过 `MethodChannel('flux/app_groups')` 把设备列表写入 App Group UserDefaults，供 Siri 快捷指令读取（非 iOS 平台静默 no-op）。
  - `favorites_service.dart`、`debouncer.dart`。
- `lib/screens/` — 页面层，基本一个文件一个 screen。
- `lib/widgets/` — 复用 UI（`GlassCard`、`BouncyButton`、`SmartSlider`、`AnimatedBackground` 等），玻璃拟态视觉风格集中在这里。

### 数据流约定

- 设备列表 `DeviceListNotifier` 持久化在 SharedPreferences (`AppConstants.keyDevices`)，每次写入都会同步到 iOS App Group，所以**新增涉及设备增删的代码点都要走 `DeviceListNotifier` 而不是直接写 prefs**。
- 滑块类操作（亮度、颜色）走 `services/debouncer.dart` 防抖；常量 `WledConstants.debounceDelay = 300ms`、`throttleInterval = 100ms` 是协议侧调试出来的经验值，调整时谨慎。
- "Optimistic UI"：UI 立即更新本地 state，再异步发请求；网络失败的回滚逻辑分散在 provider 内部，新增 mutation 时保持同样的模式。

## Native iOS 集成

- **iOS / macOS 已完全摆脱 CocoaPods，仅使用 Swift Package Manager**（2026-05-06 完成迁移）。仓库里**不存在** `ios/Podfile` / `ios/Podfile.lock` / `ios/Pods/`，新增原生依赖请走 SPM；**不要为了"修问题"重新引入 `pod install` 或 Podfile**。Flutter 自动生成的本地包路径是 `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`。
- iOS 工程内有手写的 Swift 代码（不属于 Flutter 生成产物，请勿删）：
  - `ios/Runner/WLEDAppIntents.swift` — App Intents / Siri 快捷指令定义。
  - `ios/Runner/WLEDService.swift` — Intent 内调用的 WLED HTTP 客户端。
  - `ios/Runner/Runner.entitlements` — 启用 App Groups。
- Dart → Native 通道是 `flux/app_groups`，仅一个 `syncDevices` 方法。新增 method 时两端都要改。

## Versioning

`pubspec.yaml` 中 `version: <semver>+<build>` 同时驱动 Android `versionName`/`versionCode` 和 iOS `CFBundleShortVersionString`/`CFBundleVersion`，发布前请 bump 两个段。`CHANGELOG.md` 是手写维护。

## Docs 索引

`docs/` 下的中文文档不进入 App，但是回答用户问题、写发布说明、做架构决策时的权威来源。

- [`docs/架构设计.md`](docs/架构设计.md) — 「极简 / 防御性 / 响应优先」三大设计原则与技术选型论证；做架构级决策（新增层、换状态管理、改网络栈）前先读它。
- [`docs/贡献指南.md`](docs/贡献指南.md) — Core Philosophy 与代码风格约定；写 PR / 评审时的尺子。
- [`docs/任务清单.md`](docs/任务清单.md) — 历史 roadmap（"Flux Project Tasks"，仍用旧名），已完成项的清单，可作为补全测试 / 反推意图的参考；不是当前 backlog。
- [`docs/帮助与支持.md`](docs/帮助与支持.md) — 面向终端用户的 FAQ（mDNS 搜不到设备等）；改用户可见行为前对照里面的承诺。
- [`docs/应用商店元数据.md`](docs/应用商店元数据.md) — App Store / 国内商店上架文案、关键词、描述的权威版本；改对外名称、宣传语时改这里而不是各自商店后台。
- [`docs/隐私政策.md`](docs/隐私政策.md) — 上架必交的隐私政策正文；任何新增数据收集 / 第三方 SDK 都要回头同步这份。
