import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/duo_providers.dart';
import 'package:flux/screens/adaptive_shell.dart';
import 'package:flux/widgets/widgets.dart';

/// B 方案探针：折叠屏上「添加设备 / 更多」交给**系统**工具栏。
///
/// 这里守的是**替代关系**：两者不能同时出现，也不能同时消失——
/// 同时出现是重复入口，同时消失是入口全丢。
/// 系统栏本身长什么样由 iOS 决定，Dart 侧测不到，只能靠真机截图。
const Size _innerScreen = Size(951, 669);

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

/// `flutter_animate` 在 initState 里挂零时长 Timer，测试结束时会触发
/// 「A Timer is still pending」——框架假红，与本文件的判据无关，排空即可。
void _toolbarTest(String description, Future<void> Function(WidgetTester) body) {
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
  _toolbarTest('折叠屏：自绘动作行让位给系统工具栏，不重复出现', (tester) async {
    await _pumpShell(
      tester,
      geometry: const DuoGeometry(supported: true, attached: true),
    );

    expect(find.byType(DuoSystemToolbar), findsOneWidget);
    expect(find.byKey(const ValueKey('device-list-add')), findsNothing);
  });

  _toolbarTest('非折叠设备：没有系统工具栏，自绘行一个不少', (tester) async {
    await _pumpShell(tester, geometry: DuoGeometry.unsupported);

    expect(find.byType(DuoSystemToolbar), findsNothing);
    expect(find.byKey(const ValueKey('device-list-add')), findsOneWidget);
  });
}
