import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/device_list_screen.dart';
import 'package:flux/widgets/device_card.dart';
import 'package:flux/widgets/device_overview_bar.dart';

const device = WledDevice(
  id: 'feedback',
  name: '一台名字比较长的灯带',
  originalName: 'WLED',
  ip: '192.168.100.199',
);

Future<void> host(
  WidgetTester tester,
  Widget child, {
  bool loading = false,
}) async {
  tester.view.physicalSize = const Size(340, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        l10nProvider.overrideWithValue(ZhStrings()),
        deviceSessionProvider.overrideWith(
          (ref, id) => DeviceStateNotifier(
            null,
            ref,
            deviceId: id,
            initialState: loading ? null : const WledState(on: true, bri: 128),
          ),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('首次连接显示正在连接，大字状态不溢出', (tester) async {
    await host(
      tester,
      DeviceCard(device: device, onTap: () {}, onDelete: () {}),
      loading: true,
    );
    expect(find.text('正在连接'), findsOneWidget);
    expect(find.text('连接异常'), findsNothing);
    expect(tester.takeException(), isNull);
    await drain(tester);
  });

  testWidgets('窄列表大字下标题与概览重排，概览热区至少44pt', (tester) async {
    await host(tester, const DeviceListScreen());
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(DeviceOverviewBar)).height,
      greaterThanOrEqualTo(44),
    );
    await drain(tester);
  });
}
