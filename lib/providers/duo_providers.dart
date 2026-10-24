import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/duo_geometry_service.dart';

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
