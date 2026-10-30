import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/constants.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/wled_device.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/group_providers.dart';
import 'package:flux/screens/custom_palette_editor_screen.dart';
import 'package:flux/screens/groups_management_screen.dart';

const longGroup = '客厅与餐厅的超长分组名称用于检查添加成员弹层的可用区域';

Future<void> host(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(320, 680),
  double textScale = 2,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'wled_device_groups': [
      jsonEncode({'id': 'living', 'name': longGroup, 'deviceIds': <String>[]}),
    ],
    AppConstants.keyDevices: jsonEncode([
      const WledDevice(
        id: 'one',
        name: '客厅灯',
        originalName: 'WLED',
        ip: '10.0.0.1',
      ).toJson(),
    ]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        l10nProvider.overrideWithValue(ZhStrings()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('自定义调色板窄屏两倍字可添加色标且无溢出', (tester) async {
    await host(tester, const CustomPaletteEditorScreen());
    expect(tester.takeException(), isNull);
    final add = find.text(ZhStrings().addColorStop);
    await Scrollable.ensureVisible(tester.element(add), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('长分组名在窄屏大字添加成员弹层仍可选设备', (tester) async {
    await host(
      tester,
      const GroupsManagementScreen(),
      size: const Size(466, 678),
    );
    expect(tester.takeException(), isNull);
    final add = find.text('添加成员设备');
    await Scrollable.ensureVisible(tester.element(add), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(466, 360);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await Scrollable.ensureVisible(
      tester.element(find.text('客厅灯')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    expect(find.text('客厅灯').hitTestable(), findsOneWidget);
    await tester.tap(find.text('客厅灯'));
    await tester.pumpAndSettle();
    expect(find.text('添加设备到 "$longGroup"'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroupsManagementScreen)),
    );
    expect(container.read(deviceGroupsProvider).single.deviceIds, ['one']);
    expect(find.text('客厅灯'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
