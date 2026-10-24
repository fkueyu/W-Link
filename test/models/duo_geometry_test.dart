import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flux/models/duo_geometry.dart';

/// 载荷形状与 `ios/Runner/DuoGeometryBridge.swift` 的 `geometrySnapshot()` 一致。
Map<String, Object?> _snapshot({
  Map<String, Object?>? hinge,
  List<Map<String, Object?>> divisions = const [],
  List<Map<String, Object?>> occlusions = const [],
  double width = 466,
  double height = 678,
  bool attached = true,
}) => {
  'supported': true,
  'attached': attached,
  'viewWidth': width,
  'viewHeight': height,
  'scale': 3.0,
  'hinge': ?hinge,
  'divisions': divisions,
  'occlusions': occlusions,
};

Map<String, Object?> _region(
  double x,
  double y,
  double w,
  double h, {
  bool active = true,
}) => {
  'x': x,
  'y': y,
  'width': w,
  'height': h,
  'insetTop': 0.0,
  'insetLeft': 0.0,
  'insetBottom': 0.0,
  'insetRight': 0.0,
  'active': active,
};

void main() {
  group('DuoGeometry.fromPlatform', () {
    test('外屏实测快照：右侧 84pt 遮挡区解析成一条竖条，且不触发单栏', () {
      // 2026-10-24 在 Duo 模拟器上量到 padding = EdgeInsets(0, 0, 84, 34)。
      // 遮挡区应当与其一致：x=382、宽 84、高 678。
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          hinge: {'status': 'closed', 'statusRaw': 1, 'angleRadians': 0.0},
          occlusions: [_region(382, 0, 84, 678)],
        ),
      );

      expect(geometry.supported, isTrue);
      expect(geometry.attached, isTrue);
      expect(geometry.hinge!.status, DuoHingeStatus.closed);
      expect(geometry.occlusionRegions, hasLength(1));
      expect(
        geometry.occlusionRegions.single.rect,
        const Rect.fromLTWH(382, 0, 84, 678),
      );

      // 合上时没有折叠分区，横竖都不能有——否则外屏会被误判成折叠态。
      expect(geometry.verticalFoldX, isNull);
      expect(geometry.horizontalFoldY, isNull);
      expect(geometry.needsSinglePane, isFalse);
    });

    test('内屏竖折：分区是 40pt 宽的竖条，折叠线取其中线', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          hinge: {'status': 'fullyOpen', 'statusRaw': 3, 'angleRadians': 3.05},
          divisions: [_region(455, 0, 40, 669)],
          width: 951,
          height: 669,
        ),
      );

      expect(geometry.verticalFoldX, 475.0);
      expect(geometry.horizontalFoldY, isNull);
      expect(geometry.needsSinglePane, isFalse);
    });

    test('半折（partiallyOpen）必须单栏，哪怕没有分区', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          hinge: {
            'status': 'partiallyOpen',
            'statusRaw': 2,
            'angleRadians': 1.57,
          },
        ),
      );

      expect(geometry.hinge!.isPartiallyOpen, isTrue);
      expect(geometry.hinge!.angleDegrees, closeTo(90, 0.1));
      expect(geometry.needsSinglePane, isTrue);
    });

    test('横折：折叠线取 y 中线，并且强制单栏', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          divisions: [_region(0, 310, 951, 40)],
          width: 951,
          height: 669,
        ),
      );

      expect(geometry.horizontalFoldY, 330.0);
      expect(geometry.verticalFoldX, isNull);
      expect(geometry.needsSinglePane, isTrue);
    });

    test('非活动分区不参与布局', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          divisions: [_region(455, 0, 40, 669, active: false)],
          width: 951,
        ),
      );

      expect(geometry.divisionRegions, hasLength(1));
      expect(geometry.activeDivision, isNull);
      expect(geometry.verticalFoldX, isNull);
      expect(geometry.needsSinglePane, isFalse);
    });

    test('未知状态名落到 unknown，不抛异常', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(
          hinge: {
            'status': 'somethingNew',
            'statusRaw': 99,
            'angleRadians': 1.0,
          },
        ),
      );

      expect(geometry.hinge!.status, DuoHingeStatus.unknown);
    });

    test('状态名缺失时按原始数值兜底', () {
      final geometry = DuoGeometry.fromPlatform(
        _snapshot(hinge: {'statusRaw': 2, 'angleRadians': 1.2}),
      );

      expect(geometry.hinge!.status, DuoHingeStatus.partiallyOpen);
    });
  });

  group('退化路径', () {
    test('supported=false（系统低于 iOS 27.1）', () {
      final geometry = DuoGeometry.fromPlatform({
        'supported': false,
        'reason': 'ios_below_27_1',
      });

      expect(geometry.supported, isFalse);
      expect(geometry.verticalFoldX, isNull);
      expect(geometry.needsSinglePane, isFalse);
    });

    test('null / 非 Map 载荷', () {
      expect(DuoGeometry.fromPlatform(null).supported, isFalse);
      expect(DuoGeometry.fromPlatform('oops').supported, isFalse);
      expect(DuoGeometry.fromPlatform([1, 2, 3]).supported, isFalse);
    });

    test('畸形分区被逐条跳过，其余仍然可用', () {
      final geometry = DuoGeometry.fromPlatform({
        'supported': true,
        'attached': true,
        'viewWidth': 951,
        'viewHeight': 669,
        'scale': 3,
        'divisions': [
          {'x': 1, 'y': 2}, // 缺宽高
          {'x': 'a', 'y': 2, 'width': 40, 'height': 669}, // 类型错误
          _region(455, 0, 40, 669),
          'not a map',
        ],
      });

      expect(geometry.divisionRegions, hasLength(1));
      expect(geometry.verticalFoldX, 475.0);
    });

    test('未附着（启动早期视图还没挂上）不算不支持', () {
      final geometry = DuoGeometry.fromPlatform(_snapshot(attached: false));

      expect(geometry.supported, isTrue);
      expect(geometry.attached, isFalse);
    });
  });

  group('相等性', () {
    test('同一快照两次解析相等（用于去重，避免重复重建）', () {
      final payload = _snapshot(
        hinge: {'status': 'closed', 'statusRaw': 1, 'angleRadians': 0.0},
        divisions: [_region(455, 0, 40, 669)],
      );

      expect(
        DuoGeometry.fromPlatform(payload),
        DuoGeometry.fromPlatform(payload),
      );
      expect(
        DuoGeometry.fromPlatform(payload).hashCode,
        DuoGeometry.fromPlatform(payload).hashCode,
      );
    });

    test('折叠线移动后不再相等', () {
      final before = DuoGeometry.fromPlatform(
        _snapshot(divisions: [_region(455, 0, 40, 669)]),
      );
      final after = DuoGeometry.fromPlatform(
        _snapshot(divisions: [_region(400, 0, 40, 669)]),
      );

      expect(before, isNot(after));
    });
  });
}
