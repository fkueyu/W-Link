import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 铰链状态。数值与 iOS `UIHinge.Status` 一致，便于对照原生日志。
enum DuoHingeStatus {
  unknown(0),
  closed(1),
  partiallyOpen(2),
  fullyOpen(3);

  const DuoHingeStatus(this.rawValue);

  final int rawValue;

  static DuoHingeStatus fromName(Object? name, {int? raw}) {
    if (name is String) {
      for (final value in DuoHingeStatus.values) {
        if (value.name == name) return value;
      }
    }
    if (raw != null) {
      for (final value in DuoHingeStatus.values) {
        if (value.rawValue == raw) return value;
      }
    }
    return DuoHingeStatus.unknown;
  }
}

/// 铰链角度。`angle` 的单位是弧度（与 UIKit 一致）。
class DuoHinge {
  const DuoHinge({required this.status, required this.angleRadians});

  final DuoHingeStatus status;
  final double angleRadians;

  double get angleDegrees => angleRadians * 180 / math.pi;

  /// 半折（帐篷/书本立起）。此时屏幕被物理切成两半，横向双栏会把内容拦腰切断。
  bool get isPartiallyOpen => status == DuoHingeStatus.partiallyOpen;

  @override
  bool operator ==(Object other) =>
      other is DuoHinge &&
      other.status == status &&
      other.angleRadians == angleRadians;

  @override
  int get hashCode => Object.hash(status, angleRadians);

  @override
  String toString() =>
      'DuoHinge(${status.name}, ${angleDegrees.toStringAsFixed(1)}°)';
}

/// 一块保留区。`rect` 在 Flutter 的逻辑像素坐标系里。
class DuoRegion {
  const DuoRegion({
    required this.rect,
    required this.isActive,
    this.margins = EdgeInsets.zero,
  });

  final Rect rect;
  final bool isActive;
  final EdgeInsets margins;

  /// 竖折（细高的竖条）——折叠线是竖直的。
  bool get isVerticalFold => rect.height > rect.width;

  /// 横折（扁宽的横条）——折叠线是水平的。
  bool get isHorizontalFold => rect.width >= rect.height;

  @override
  bool operator ==(Object other) =>
      other is DuoRegion &&
      other.rect == rect &&
      other.isActive == isActive &&
      other.margins == margins;

  @override
  int get hashCode => Object.hash(rect, isActive, margins);

  @override
  String toString() =>
      'DuoRegion(${rect.left.toStringAsFixed(1)},'
      '${rect.top.toStringAsFixed(1)},'
      '${rect.width.toStringAsFixed(1)}x${rect.height.toStringAsFixed(1)}'
      '${isActive ? '' : ' inactive'})';
}

/// 折叠屏几何快照。
///
/// 两个来源，缺一不可：
/// - [divisionRegions]：折叠线位置（HIG 说的「分区」）；
/// - [hinge]：铰链状态与角度（帐篷姿态靠它）。
///
/// 两者都拿不到时 [supported] 为 false，所有 getter 返回 null，
/// 布局与普通 iPhone 完全一致——桥坏了也不会改变现有观感。
class DuoGeometry {
  const DuoGeometry({
    this.supported = false,
    this.attached = false,
    this.hinge,
    this.divisionRegions = const [],
    this.occlusionRegions = const [],
    this.viewSize = Size.zero,
    this.scale = 1,
  });

  static const DuoGeometry unsupported = DuoGeometry();

  final bool supported;
  final bool attached;
  final DuoHinge? hinge;
  final List<DuoRegion> divisionRegions;
  final List<DuoRegion> occlusionRegions;
  final Size viewSize;
  final double scale;

  /// 当前活动的分区（折叠线）。没有就是 null。
  DuoRegion? get activeDivision {
    for (final region in divisionRegions) {
      if (region.isActive) return region;
    }
    return null;
  }

  /// 竖直折叠线的 x 坐标（逻辑像素）。没有竖折时为 null。
  double? get verticalFoldX {
    final division = activeDivision;
    if (division == null || !division.isVerticalFold) return null;
    return division.rect.center.dx;
  }

  /// 水平折叠线的 y 坐标（逻辑像素）。没有横折时为 null。
  double? get horizontalFoldY {
    final division = activeDivision;
    if (division == null || !division.isHorizontalFold) return null;
    return division.rect.center.dy;
  }

  /// 半折或横折时不能横向排版：内容会被折痕拦腰切断。
  bool get needsSinglePane {
    if (hinge?.isPartiallyOpen ?? false) return true;
    return horizontalFoldY != null;
  }

  /// 从平台通道的原始字典解析。任何字段缺失/类型不符都退回安全默认值。
  factory DuoGeometry.fromPlatform(Object? raw) {
    if (raw is! Map) return DuoGeometry.unsupported;

    final supported = raw['supported'] == true;
    if (!supported) return DuoGeometry.unsupported;

    final hingeRaw = raw['hinge'];
    DuoHinge? hinge;
    if (hingeRaw is Map) {
      final angle = _toDouble(hingeRaw['angleRadians']);
      hinge = DuoHinge(
        status: DuoHingeStatus.fromName(
          hingeRaw['status'],
          raw: hingeRaw['statusRaw'] is num
              ? (hingeRaw['statusRaw'] as num).toInt()
              : null,
        ),
        angleRadians: angle ?? 0,
      );
    }

    return DuoGeometry(
      supported: true,
      attached: raw['attached'] == true,
      hinge: hinge,
      divisionRegions: _parseRegions(raw['divisions']),
      occlusionRegions: _parseRegions(raw['occlusions']),
      viewSize: Size(
        _toDouble(raw['viewWidth']) ?? 0,
        _toDouble(raw['viewHeight']) ?? 0,
      ),
      scale: _toDouble(raw['scale']) ?? 1,
    );
  }

  static List<DuoRegion> _parseRegions(Object? raw) {
    if (raw is! List) return const [];
    final result = <DuoRegion>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final x = _toDouble(item['x']);
      final y = _toDouble(item['y']);
      final width = _toDouble(item['width']);
      final height = _toDouble(item['height']);
      if (x == null || y == null || width == null || height == null) continue;
      result.add(
        DuoRegion(
          rect: Rect.fromLTWH(x, y, width, height),
          isActive: item['active'] == true,
          margins: EdgeInsets.fromLTRB(
            _toDouble(item['insetLeft']) ?? 0,
            _toDouble(item['insetTop']) ?? 0,
            _toDouble(item['insetRight']) ?? 0,
            _toDouble(item['insetBottom']) ?? 0,
          ),
        ),
      );
    }
    return result;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DuoGeometry &&
      other.supported == supported &&
      other.attached == attached &&
      other.hinge == hinge &&
      listEquals(other.divisionRegions, divisionRegions) &&
      listEquals(other.occlusionRegions, occlusionRegions) &&
      other.viewSize == viewSize &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    supported,
    attached,
    hinge,
    Object.hashAll(divisionRegions),
    Object.hashAll(occlusionRegions),
    viewSize,
    scale,
  );

  @override
  String toString() =>
      'DuoGeometry(supported: $supported, attached: $attached, '
      'hinge: $hinge, divisions: $divisionRegions, '
      'occlusions: $occlusionRegions, '
      'view: ${viewSize.width.toStringAsFixed(1)}x'
      '${viewSize.height.toStringAsFixed(1)} @${scale}x)';
}
