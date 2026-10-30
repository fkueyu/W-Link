import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/models.dart';

/// 折叠屏几何服务。
///
/// 原生侧是 `ios/Runner/DuoGeometryBridge.swift`：Flutter 引擎在 iOS 上不提供折叠
/// 信息（`displayFeatures` 只填 Android），只能用 UIKit 的 `UIHingeInteraction`
/// 与 `reservedRegions(of:)` 取，再从 `flux/duo` 通道送过来。
///
/// 设计约定：**拿不到就当作没有**。通道缺失、系统低于 iOS 27.1、载荷畸形，
/// 一律返回 [DuoGeometry.unsupported]，调用方的布局与普通 iPhone 完全一致。
class DuoGeometryService {
  DuoGeometryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'flux/duo';

  final MethodChannel _channel;
  final StreamController<DuoGeometry> _controller =
      StreamController<DuoGeometry>.broadcast();

  DuoGeometry? _last;
  bool _started = false;
  bool _disposed = false;
  int _attachRetries = 0;
  Timer? _retryTimer;
  late final _MetricsObserver _observer = _MetricsObserver(this);

  /// 读一次快照。任何异常都退化成 [DuoGeometry.unsupported]。
  Future<DuoGeometry> read() async {
    if (_disposed) return DuoGeometry.unsupported;
    try {
      final raw = await _channel.invokeMethod<Object?>('getGeometry');
      return DuoGeometry.fromPlatform(raw);
    } on MissingPluginException {
      // 非 iOS、或系统低于 27.1 时原生侧没注册——这是正常退化路径。
      return DuoGeometry.unsupported;
    } on PlatformException {
      return DuoGeometry.unsupported;
    }
  }

  /// 首次读取 + 铰链变化 + 布局尺寸变化时重新读取。
  Stream<DuoGeometry> watch() {
    if (!_started) _start();
    return _controller.stream;
  }

  void _start() {
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onHinge') await _refresh();
      return null;
    });
    WidgetsBinding.instance.addObserver(_observer);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    final geometry = await read();
    if (_disposed) return;

    if (_last != geometry) {
      _last = geometry;
      _controller.add(geometry);
    }

    // 启动早期 FlutterViewController 的 view 可能还没挂上，桥会返回 attached=false。
    // 用一个短重试兜住这个窗口，之后交给尺寸变化与铰链事件驱动。
    if (geometry.supported && !geometry.isFoldable && !_disposed) {
      if (_attachRetries < 5) {
        _attachRetries++;
        _retryTimer?.cancel();
        _retryTimer = Timer(
          const Duration(milliseconds: 200),
          () => unawaited(_refresh()),
        );
      }
    } else {
      _attachRetries = 0;
    }
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(_observer);
    _channel.setMethodCallHandler(null);
    if (!_controller.isClosed) _controller.close();
  }
}

class _MetricsObserver extends WidgetsBindingObserver {
  _MetricsObserver(this._service);

  final DuoGeometryService _service;

  @override
  void didChangeMetrics() {
    unawaited(_service._refresh());
  }
}
