import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/duo_geometry_service.dart';
import '../services/duo_toolbar_service.dart';

/// 折叠屏几何服务实例。
final duoGeometryServiceProvider = Provider<DuoGeometryService>((ref) {
  final service = DuoGeometryService();
  ref.onDispose(service.dispose);
  return service;
});

/// 当前折叠屏几何。非折叠设备上恒为 [DuoGeometry.unsupported]。
///
/// 用 `.valueOrNull` 读：还没读到第一帧时按「没有折叠信息」处理，
/// 不要把首帧当成「不支持」去做降级分支。
final duoGeometryProvider = StreamProvider<DuoGeometry>((ref) {
  return ref.watch(duoGeometryServiceProvider).watch();
});

/// 系统工具栏服务（B 方案探针）。非 iOS 上所有调用都是 no-op。
final duoToolbarServiceProvider = Provider<DuoToolbarService>((ref) {
  return DuoToolbarService();
});

/// 可见页面原生按钮下发或显示失败时，立即恢复 Flutter 入口。
final duoToolbarFallbackProvider = StateProvider<bool>((ref) => false);

/// 真实折叠设备且原生安装成功后，才允许撤下 Flutter 动作入口。
final duoToolbarReadyProvider = FutureProvider<bool>((ref) {
  if (ref.watch(duoGeometryProvider).valueOrNull?.isFoldable != true) {
    return false;
  }
  var disposed = false;
  Timer? retry;
  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
  });
  if (ref.watch(duoToolbarFallbackProvider)) {
    retry = Timer(const Duration(milliseconds: 500), () {
      ref.read(duoToolbarFallbackProvider.notifier).state = false;
    });
    // 同步返回 false，避免 AsyncLoading 继续携带上次的 true。
    return false;
  }
  final service = ref.watch(duoToolbarServiceProvider);
  return service.ensureAttached().then((ready) {
    if (!ready && !disposed) {
      // 冷启动窗口可能尚未就绪；保持 Flutter 入口并在稍后重试。
      retry = Timer(const Duration(milliseconds: 500), ref.invalidateSelf);
    }
    return ready;
  });
});
