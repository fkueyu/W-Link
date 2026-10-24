import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/duo_providers.dart';
import 'package:flux/screens/adaptive_shell.dart';

/// Duo 内屏：951×669。折痕是 40pt 宽的竖条，落在 455…495，中线 475。
const Size _innerScreen = Size(951, 669);

DuoRegion _verticalFold({double left = 455, bool active = true}) =>
    DuoRegion(rect: Rect.fromLTWH(left, 0, 40, 669), isActive: active);

DuoRegion _horizontalFold({double top = 310}) =>
    DuoRegion(rect: Rect.fromLTWH(0, top, 951, 40), isActive: true);

DuoGeometry _geometry({
  DuoHingeStatus? hingeStatus,
  double angle = 3.05,
  List<DuoRegion> divisions = const [],
}) => DuoGeometry(
  supported: true,
  attached: true,
  hinge: hingeStatus == null
      ? null
      : DuoHinge(status: hingeStatus, angleRadians: angle),
  divisionRegions: divisions,
  viewSize: _innerScreen,
  scale: 3,
);

Future<void> _pumpShell(
  WidgetTester tester, {
  required DuoGeometry geometry,
  Size size = _innerScreen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        duoGeometryProvider.overrideWith((ref) => Stream.value(geometry)),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AdaptiveShell(),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _paneWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const Key(kDeviceListPaneKey))).width;

/// `flutter_animate` 在 initState 里挂一个零时长 Timer；测试结束时它还挂着会触发
/// 「A Timer is still pending」——那是框架的假红，与本文件的判据无关，排空即可。
void _foldTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

void main() {
  _foldTest('拿不到折叠信息时，双栏与改动前一致（左栏 340 + 分隔线）', (tester) async {
    await _pumpShell(tester, geometry: DuoGeometry.unsupported);

    expect(find.byKey(const Key(kSplitRowKey)), findsOneWidget);
    expect(_paneWidth(tester), 340);
    expect(find.byKey(const Key(kSplitDividerKey)), findsOneWidget);
  });

  _foldTest('竖折时左栏宽度对齐折痕，右栏从折痕起，且不再画分隔线', (tester) async {
    await _pumpShell(tester, geometry: _geometry(divisions: [_verticalFold()]));

    expect(find.byKey(const Key(kSplitRowKey)), findsOneWidget);
    expect(_paneWidth(tester), 475);
    expect(find.byKey(const Key(kSplitDividerKey)), findsNothing);

    final detail = find.byKey(const Key(kDetailPaneKey));
    expect(tester.getTopLeft(detail).dx, 475);
    expect(tester.getSize(detail).width, closeTo(951 - 475, 0.01));
  });

  _foldTest('折痕太靠近边缘时不硬套，退回固定 340', (tester) async {
    await _pumpShell(
      tester,
      geometry: _geometry(divisions: [_verticalFold(left: 210)]),
    );

    expect(_paneWidth(tester), 340);
    expect(find.byKey(const Key(kSplitDividerKey)), findsOneWidget);
  });

  _foldTest('非活动分区不改变布局', (tester) async {
    await _pumpShell(
      tester,
      geometry: _geometry(divisions: [_verticalFold(active: false)]),
    );

    expect(_paneWidth(tester), 340);
  });

  _foldTest('半折（帐篷）退回单栏：横向双栏会被折痕拦腰切断', (tester) async {
    await _pumpShell(
      tester,
      geometry: _geometry(
        hingeStatus: DuoHingeStatus.partiallyOpen,
        angle: 1.57,
      ),
    );

    expect(find.byKey(const Key(kSplitRowKey)), findsNothing);
    expect(find.byKey(const Key(kDeviceListPaneKey)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _foldTest('横折同样退回单栏', (tester) async {
    await _pumpShell(
      tester,
      geometry: _geometry(divisions: [_horizontalFold()]),
    );

    expect(find.byKey(const Key(kSplitRowKey)), findsNothing);
  });

  _foldTest('完全展开且无分区：维持双栏（铰链开着不等于有折痕）', (tester) async {
    await _pumpShell(
      tester,
      geometry: _geometry(hingeStatus: DuoHingeStatus.fullyOpen),
    );

    expect(find.byKey(const Key(kSplitRowKey)), findsOneWidget);
    expect(_paneWidth(tester), 340);
  });

  _foldTest('外屏（466 宽）即便报告了铰链也不进双栏', (tester) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpShell(
      tester,
      geometry: _geometry(hingeStatus: DuoHingeStatus.closed),
      size: const Size(466, 678),
    );

    // 466 < 800 断点：走单栏 push 布局。
    expect(find.byKey(const Key(kSplitRowKey)), findsNothing);
  });
}
