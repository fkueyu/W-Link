import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 系统栏菜单项。镜像 iOS 的 `UIAction`，由原生侧构造成 `UIMenu`。
class DuoToolbarMenuEntry {
  const DuoToolbarMenuEntry({
    required this.id,
    required this.title,
    this.symbol,
    this.destructive = false,
  });

  final String id;
  final String title;

  /// SF Symbol 名。为 null 时原生侧不给图标。
  final String? symbol;
  final bool destructive;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    if (symbol != null) 'symbol': symbol,
    'destructive': destructive,
  };
}

/// 系统工具栏服务（B 方案探针）。
///
/// 原生侧是 `ios/Runner/DuoToolbarBridge.swift`：它把 Flutter 内容装进
/// `UINavigationController`，两个头部动作变成真正的 `UIBarButtonItem`。
/// 只有真正的系统条才会被 iOS 27.1 在 Duo 上竖排到右侧——这是本探针要验证的事。
///
/// 约定：**非 iOS 一律 no-op**；通道缺失、参数异常都静默吞掉，
/// 保证「拿不到系统栏」时 App 与改动前完全一致。
class DuoToolbarService {
  DuoToolbarService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const String channelName = 'flux/duo_toolbar';

  final MethodChannel _channel;

  /// 原生侧回调。由 [DuoSystemToolbar] 在每次同步时挂上去。
  VoidCallback? onAddTap;
  ValueChanged<String>? onMenuSelect;

  bool _visible = false;
  String? _itemsSignature;

  /// 只在 iOS 上尝试；其他平台直接返回，避免无谓的通道调用。
  bool get isSupported => !kIsWeb && Platform.isIOS;

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onAddTap') {
      onAddTap?.call();
    } else if (call.method == 'onMenuSelect') {
      final args = call.arguments;
      if (args is Map && args['id'] is String) {
        onMenuSelect?.call(args['id'] as String);
      }
    }
    return null;
  }

  /// 显示/隐藏系统栏。重复调用同一状态不会走通道。
  Future<void> setVisible(bool visible) async {
    if (!isSupported || _visible == visible) return;
    _visible = visible;
    await _invoke('setVisible', {'visible': visible});
  }

  /// 下发按钮与菜单。内容不变时不重复下发（每次 build 都会调）。
  Future<void> setItems({
    required String addLabel,
    required String moreLabel,
    required List<DuoToolbarMenuEntry> menu,
  }) async {
    if (!isSupported) return;
    final signature = '$addLabel|$moreLabel|'
        '${menu.map((e) => '${e.id}:${e.title}:${e.symbol}:${e.destructive}').join(",")}';
    if (_itemsSignature == signature) return;
    _itemsSignature = signature;
    await _invoke('setItems', {
      'addLabel': addLabel,
      'moreLabel': moreLabel,
      'menu': menu.map((e) => e.toMap()).toList(),
    });
  }

  /// 探针用：原生壳是否真的装上了。
  Future<bool> isAttached() async {
    if (!isSupported) return false;
    try {
      final raw = await _channel.invokeMethod<Object?>('isAttached');
      return raw is Map && raw['attached'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      // 原生侧没注册——正常退化路径。
    } on PlatformException catch (error) {
      debugPrint('[DuoToolbar] $method failed: ${error.message}');
    }
  }
}
