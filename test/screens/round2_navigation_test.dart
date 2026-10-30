// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/constants.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/models.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/providers/duo_providers.dart';
import 'package:flux/screens/adaptive_shell.dart';
import 'package:flux/screens/device_control_screen.dart';
import 'package:flux/screens/device_list_screen.dart';
import 'package:flux/services/wled_api_service.dart';
import 'package:flux/widgets/device_card.dart';
import 'package:flux/widgets/nightlight_editor.dart';
import 'package:flux/screens/nightlight_screen.dart';
import 'package:flux/widgets/device_settings_sheet.dart';

const device = WledDevice(
  id: 'review-device',
  name: '审查灯带',
  originalName: 'WLED',
  ip: '10.0.0.9',
);

class AuditApi extends WledApiService {
  AuditApi()
    : super(
        baseUrl: 'http://10.0.0.9',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
  final pending = Completer<Map<String, dynamic>>();
  final savedIds = <int>[];
  @override
  Future<Map<String, dynamic>> getPresets() => pending.future;
  @override
  Future<void> savePreset(int presetId, {String? name}) async {
    savedIds.add(presetId);
  }
}

Future<ProviderContainer> host(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(466, 678),
  WledApiService? api,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  SharedPreferences.setMockInitialValues({
    AppConstants.keyDevices: jsonEncode([device.toJson()]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        l10nProvider.overrideWithValue(ZhStrings()),
        duoGeometryProvider.overrideWith(
          (ref) => Stream.value(DuoGeometry.unsupported),
        ),
        wledApiProvider.overrideWithValue(api),
        deviceInfoProvider.overrideWith((ref) async => null),
        effectsProvider.overrideWith((ref) async => []),
        palettesProvider.overrideWith((ref) async => []),
        effectMetadataProvider.overrideWith((ref) async => []),
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
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return ProviderScope.containerOf(tester.element(find.byWidget(child)));
}

Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> select(WidgetTester tester) async {
  await tester.tap(find.byType(DeviceCard));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('宽屏选设备保留列表位置，并且没有全屏进入动画', (tester) async {
    final container = await host(
      tester,
      const AdaptiveShell(),
      size: const Size(951, 669),
    );
    for (var i = 0; i < 12; i++) {
      await container
          .read(deviceListProvider.notifier)
          .addDevice(
            WledDevice(
              id: 'more-$i',
              name: '灯带$i',
              originalName: 'WLED',
              ip: '10.0.1.${i + 1}',
            ),
          );
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(DeviceListScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(before, greaterThan(500));
    final target = tester
        .widgetList<DeviceCard>(find.byType(DeviceCard))
        .firstWhere(
          (card) =>
              find.text(card.device.name).hitTestable().evaluate().isNotEmpty,
        );
    await tester.tap(find.text(target.device.name));
    await tester.pump();
    final detail = tester.element(find.byType(DeviceControlScreen));
    expect(ModalRoute.of(detail)!.animation!.value, 1);
    await tester.pumpAndSettle();
    final after = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(DeviceListScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(after, closeTo(before, 1));
    tester.view.physicalSize = const Size(466, 678);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(951, 669);
    await tester.pumpAndSettle();
    final restored = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(DeviceListScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(restored, closeTo(before, 1));
    await drain(tester);
  });

  testWidgets('返回动画期间保留当前设备，完全退出后才清理', (tester) async {
    final container = await host(
      tester,
      const AdaptiveShell(),
      reduceMotion: false,
    );
    await select(tester);
    final element = tester.element(find.byType(DeviceControlScreen));
    final route = ModalRoute.of(element)!;
    Navigator.of(element).pop();
    await tester.pump();
    expect(route.animation!.status, AnimationStatus.reverse);
    expect(container.read(currentDeviceIdProvider), device.id);
    expect(
      find.byType(DeviceControlScreen, skipOffstage: false),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(currentDeviceIdProvider), isNull);
    await drain(tester);
  });

  testWidgets('主内容仅计算一次顶部安全区', (tester) async {
    await host(tester, const DeviceControlScreen(device: device));
    final first = tester.getTopLeft(find.text(device.name)).dy;
    tester.view.padding = const FakeViewPadding(top: 62);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final second = tester.getTopLeft(find.text(device.name)).dy;
    expect(second - first, closeTo(62, 0.1));
    await drain(tester);
  });

  for (final expanding in [false, true]) {
    testWidgets('设置弹层${expanding ? '展开' : '折叠'}后仍可进入夜灯', (tester) async {
      final api = AuditApi();
      addTearDown(api.dispose);
      await host(
        tester,
        const AdaptiveShell(),
        api: api,
        size: expanding ? const Size(466, 678) : const Size(951, 669),
      );
      await select(tester);
      await tester.tap(find.bySemanticsLabel('设备设置'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NightlightSummaryCard), findsOneWidget);
      tester.view.physicalSize = expanding
          ? const Size(951, 669)
          : const Size(466, 678);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(NightlightSummaryCard));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byType(NightlightScreen), findsOneWidget);
      expect(find.byType(DeviceSettingsSheet), findsNothing);
      await drain(tester);
    });
  }
}
