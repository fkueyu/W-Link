import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/constants.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/providers.dart';
import 'package:flux/screens/adaptive_shell.dart';
import 'package:flux/screens/device_control_screen.dart';
import 'package:flux/screens/nightlight_screen.dart';
import 'package:flux/services/duo_toolbar_service.dart';
import 'package:flux/services/wled_api_service.dart';
import 'package:flux/widgets/device_card.dart';
import 'package:flux/widgets/device_settings_sheet.dart';
import 'package:flux/widgets/nightlight_editor.dart';

class IosToolbar extends DuoToolbarService {
  IosToolbar(MethodChannel channel) : super(channel: channel);
  @override
  bool get isSupported => true;
}

const device = WledDevice(
  id: 'control',
  name: '客厅灯',
  originalName: 'WLED',
  ip: '10.0.0.8',
);

void main() {
  const channel = MethodChannel('test/control_toolbar');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'ensureAttached' ? {'attached': true} : true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<IosToolbar> host(
    WidgetTester tester, {
    bool ready = true,
    bool error = false,
    Size size = const Size(466, 678),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyDevices: jsonEncode([device.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final service = IosToolbar(channel);
    final api = WledApiService(baseUrl: device.baseUrl);
    addTearDown(api.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          l10nProvider.overrideWithValue(ZhStrings()),
          duoToolbarServiceProvider.overrideWithValue(service),
          duoToolbarReadyProvider.overrideWith((ref) async => ready),
          duoGeometryProvider.overrideWith(
            (ref) => Stream.value(DuoGeometry.unsupported),
          ),
          wledApiProvider.overrideWithValue(api),
          deviceInfoProvider.overrideWith((ref) async => null),
          effectsProvider.overrideWith((ref) async => []),
          palettesProvider.overrideWith((ref) async => []),
          effectMetadataProvider.overrideWith((ref) async => []),
          deviceStateProvider.overrideWithValue(
            error
                ? AsyncError(Exception('offline'), StackTrace.empty)
                : const AsyncData(WledState(on: true, bri: 128)),
          ),
          deviceSessionProvider.overrideWith(
            (ref, id) => DeviceStateNotifier(
              null,
              ref,
              deviceId: id,
              initialState: const WledState(on: true, bri: 128),
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const AdaptiveShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DeviceCard));
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Map items() =>
      calls.lastWhere((c) => c.method == 'setItems').arguments as Map;

  for (final size in [const Size(466, 678), const Size(951, 669)]) {
    testWidgets('控制页用系统返回和设置，折叠后及子页返回恢复 $size', (tester) async {
      final service = await host(tester, size: size);
      expect(items()['backLabel'], '设备');
      expect(items()['addSymbol'], 'slider.horizontal.3');
      expect(items()['showMenu'], false);
      expect(find.bySemanticsLabel('设备设置'), findsNothing);
      service.onAddTap?.call();
      await tester.pumpAndSettle();
      expect(find.byType(DeviceSettingsSheet), findsOneWidget);
      expect(
        (calls.lastWhere((c) => c.method == 'setVisible').arguments
            as Map)['visible'],
        false,
      );
      tester.view.physicalSize = size.width > 800
          ? const Size(466, 678)
          : const Size(951, 669);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DeviceSettingsSheet))).pop();
      await tester.pumpAndSettle();
      expect(items()['backLabel'], '设备');
      expect(
        (calls.lastWhere((c) => c.method == 'setVisible').arguments
            as Map)['visible'],
        true,
      );
      service.onAddTap?.call();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NightlightSummaryCard));
      await tester.pumpAndSettle();
      expect(find.byType(NightlightScreen), findsOneWidget);
      expect(find.byType(DeviceSettingsSheet), findsNothing);
      expect(items()['backLabel'], '返回');
      expect(items()['showPrimary'], false);
      expect(
        (calls.lastWhere((c) => c.method == 'setVisible').arguments
            as Map)['visible'],
        true,
      );
      Navigator.of(tester.element(find.byType(NightlightScreen))).pop();
      await tester.pumpAndSettle();
      expect(items()['backLabel'], '设备');
      expect(
        (calls.lastWhere((c) => c.method == 'setVisible').arguments
            as Map)['visible'],
        true,
      );
      // 列表随重命名刷新也不能抢回控制页工具栏。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceControlScreen)),
      );
      await container
          .read(deviceListProvider.notifier)
          .updateDeviceName(device.id, '新名称');
      await tester.pumpAndSettle();
      expect(items()['addSymbol'], 'slider.horizontal.3');
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onBackTap'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(DeviceControlScreen), findsNothing);
      expect(items()['addSymbol'], 'plus');
      expect(items()['backLabel'], isNull);
      await dispose(tester);
    });
  }
  testWidgets('断线时系统返回仍可用，设置禁用', (tester) async {
    await host(tester, error: true);
    expect(items()['backLabel'], '设备');
    expect(items()['addEnabled'], false);
    expect(find.text(ZhStrings().connectionFailed), findsOneWidget);
    await dispose(tester);
  });
  testWidgets('系统栏不可用时保留页面返回和设置', (tester) async {
    await host(tester, ready: false);
    expect(find.bySemanticsLabel('设备设置'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('设备设置'));
    await tester.pumpAndSettle();
    expect(find.byType(DeviceSettingsSheet), findsOneWidget);
    await dispose(tester);
  });
}
