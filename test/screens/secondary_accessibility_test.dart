import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/effects_list_screen.dart';
import 'package:flux/screens/palettes_list_screen.dart';
import 'package:flux/screens/segments_list_screen.dart';
import 'package:flux/screens/presets_list_screen.dart';
import 'package:flux/services/wled_api_service.dart';
import 'package:flux/widgets/device_settings_sheet.dart';

class LongStrings extends ZhStrings {
  @override
  String get version => '设备当前固件版本信息';
}

Future<void> host(
  WidgetTester tester,
  Widget child, {
  AppStrings? strings,
  WledState state = const WledState(on: true, bri: 128),
}) async {
  tester.view.physicalSize = const Size(320, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = WledApiService(baseUrl: 'http://127.0.0.1');
  addTearDown(api.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        l10nProvider.overrideWithValue(strings ?? ZhStrings()),
        deviceStateProvider.overrideWithValue(AsyncData(state)),
        wledApiProvider.overrideWithValue(api),
        effectsProvider.overrideWith((ref) async => []),
        presetsProvider.overrideWith((ref) async => []),
        palettesProvider.overrideWith((ref) async => []),
        deviceInfoProvider.overrideWith(
          (ref) async => const WledInfo(
            ver: '0.15.1-extended-version',
            vid: 1,
            leds: WledLedInfo(count: 60),
            name: 'test',
            mac: 'AA:BB:CC:DD:EE:FF',
          ),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final screen in [
    const EffectsListScreen(),
    const PalettesListScreen(),
    const PresetsListScreen(),
  ]) {
    testWidgets('${screen.runtimeType} 搜索随两倍字增高且能输入筛选', (tester) async {
      await host(tester, screen);
      final field = find.byType(TextField);
      expect(tester.getSize(field).height, greaterThan(44));
      await tester.enterText(field, 'test');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('设备设置中长标签和MAC在两倍字窄屏可换行', (tester) async {
    final api = WledApiService(baseUrl: 'http://127.0.0.1');
    addTearDown(api.dispose);
    await host(
      tester,
      Scaffold(
        body: DeviceSettingsSheet(
          api: api,
          state: const WledState(on: true, bri: 128),
          onOpenNightlight: () {},
        ),
      ),
      strings: LongStrings(),
    );
    await tester.scrollUntilVisible(
      find.text('MAC'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('分段页按钮有明确读屏名称且两倍字概览不溢出', (tester) async {
    await host(tester, const SegmentsListScreen());
    expect(find.bySemanticsLabel('返回'), findsOneWidget);
    expect(find.bySemanticsLabel('添加分段'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('分段高级范围参数在窄屏两倍字可读且能打开编辑', (tester) async {
    await host(
      tester,
      const SegmentsListScreen(),
      state: const WledState(
        on: true,
        bri: 128,
        info: WledInfo(
          ver: '0.15',
          vid: 1,
          name: 'test',
          leds: WledLedInfo(count: 1500),
        ),
        seg: [WledSegment(id: 0, start: 1000, stop: 1500)],
      ),
    );
    await tester.tap(find.text('高级'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('1500').last);
    await tester.pump();
    await tester.tap(find.text('1500').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
