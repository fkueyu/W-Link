import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
import 'package:flux/widgets/device_card.dart';

const _device = WledDevice(
  id: 'device-a',
  name: '客厅灯带',
  originalName: 'WLED',
  ip: '10.0.0.9',
);
const _wide = Size(951, 669);
const _narrow = Size(466, 678);

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  Size size = _wide,
  DuoGeometry geometry = DuoGeometry.unsupported,
  EdgeInsets padding = EdgeInsets.zero,
  List<WledDevice> devices = const [_device],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    AppConstants.keyDevices: jsonEncode(
      devices.map((device) => device.toJson()).toList(),
    ),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        duoGeometryProvider.overrideWith((ref) => Stream.value(geometry)),
        l10nProvider.overrideWithValue(ZhStrings()),
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
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            padding: padding,
            viewPadding: padding,
          ),
          child: child!,
        ),
        home: const AdaptiveShell(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return ProviderScope.containerOf(tester.element(find.byType(AdaptiveShell)));
}

Future<void> _select(WidgetTester tester) async {
  await tester.tap(find.byType(DeviceCard));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(DeviceControlScreen), findsOneWidget);
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('外屏右侧保留区不遮挡设备设置入口', (tester) async {
    await _mount(
      tester,
      size: _narrow,
      padding: const EdgeInsets.only(right: 84),
    );
    await _select(tester);
    expect(
      tester.getRect(find.byIcon(Icons.tune_rounded)).right,
      lessThanOrEqualTo(382),
    );
    await _drain(tester);
  });

  testWidgets('双栏从A切到B，折叠与子页返回后仍控制B', (tester) async {
    const second = WledDevice(
      id: 'device-b',
      name: '卧室灯带',
      originalName: 'WLED',
      ip: '10.0.0.10',
    );
    final container = await _mount(tester, devices: [_device, second]);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is DeviceCard && widget.device.id == _device.id,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is DeviceCard && widget.device.id == second.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(currentDeviceIdProvider), second.id);
    tester.view.physicalSize = _narrow;
    await tester.pumpAndSettle();
    final navigator = Navigator.of(
      tester.element(find.byType(DeviceControlScreen)),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('B的子页')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DeviceControlScreen>(find.byType(DeviceControlScreen))
          .device
          .id,
      second.id,
    );
    expect(container.read(currentDeviceIdProvider), second.id);
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('双栏选中设备再打开子页，不触发重复Hero', (tester) async {
    await _mount(tester);
    await _select(tester);
    Navigator.of(tester.element(find.byType(DeviceControlScreen))).push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('子页'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('子页'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('内屏合盖继续控制同一设备，返回才回列表', (tester) async {
    final container = await _mount(tester);
    await _select(tester);
    tester.view.physicalSize = _narrow;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeviceControlScreen), findsOneWidget);
    expect(container.read(currentDeviceIdProvider), _device.id);
    expect(
      tester
          .widget<DeviceControlScreen>(find.byType(DeviceControlScreen))
          .embedded,
      isFalse,
    );
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeviceControlScreen), findsNothing);
    expect(find.byType(DeviceCard), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('外屏展开后同一设备进入双栏，并显示选中语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await _mount(tester, size: _narrow);
    await _select(tester);
    tester.view.physicalSize = _wide;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key(kSplitRowKey)), findsOneWidget);
    expect(
      tester
          .widget<DeviceControlScreen>(find.byType(DeviceControlScreen))
          .embedded,
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byType(DeviceCard))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    await _drain(tester);
    semantics.dispose();
  });

  testWidgets('子页期间折叠，返回后继续同一设备', (tester) async {
    final container = await _mount(tester, size: _narrow);
    await _select(tester);
    final navigator = Navigator.of(
      tester.element(find.byType(DeviceControlScreen)),
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('保留子任务')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    tester.view.physicalSize = _wide;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('保留子任务'), findsOneWidget);
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key(kSplitRowKey)), findsOneWidget);
    expect(find.byType(DeviceControlScreen), findsOneWidget);
    expect(container.read(currentDeviceIdProvider), _device.id);
    expect(tester.takeException(), isNull);
    await _drain(tester);
  });

  testWidgets('删除选中设备清理详情，重命名取最新设备', (tester) async {
    final container = await _mount(tester);
    await _select(tester);
    await container
        .read(deviceListProvider.notifier)
        .updateDeviceName(_device.id, '新的设备名');
    await tester.pump();
    expect(
      tester
          .widget<DeviceControlScreen>(find.byType(DeviceControlScreen))
          .device
          .name,
      '新的设备名',
    );
    await container.read(deviceListProvider.notifier).removeDevice(_device.id);
    await tester.pump();
    expect(find.byType(DeviceControlScreen), findsNothing);
    expect(container.read(currentDeviceIdProvider), isNull);
    await _drain(tester);
  });

  testWidgets('左安全区存在时，详情仍从视图折痕坐标开始', (tester) async {
    await _mount(
      tester,
      padding: const EdgeInsets.only(left: 84),
      geometry: const DuoGeometry(
        supported: true,
        attached: true,
        divisionRegions: [
          DuoRegion(rect: Rect.fromLTWH(455, 0, 40, 669), isActive: true),
        ],
      ),
    );
    expect(tester.getTopLeft(find.byKey(const Key(kDetailPaneKey))).dx, 475);
    await _drain(tester);
  });
}
