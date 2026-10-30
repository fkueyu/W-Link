import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/core/constants.dart';
import 'package:flux/core/l10n.dart';
import 'package:flux/models/wled_device.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/device_providers.dart';
import 'package:flux/screens/custom_palette_editor_screen.dart';
import 'package:flux/widgets/bouncy_button.dart';

void main() {
  const device = WledDevice(
    id: 'palette-target',
    name: '灯带',
    originalName: 'WLED',
    ip: '10.0.0.8',
    port: 8088,
  );
  Future<void> mount(WidgetTester tester, {bool selected = true}) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyDevices: jsonEncode([device.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentDeviceIdProvider.overrideWith(
            (ref) => selected ? device.id : null,
          ),
          l10nProvider.overrideWithValue(ZhStrings()),
        ],
        child: const MaterialApp(home: CustomPaletteEditorScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('调色板上传保留设备配置的非默认端口', (tester) async {
    Uri? target;
    await http.runWithClient(
      () async {
        await mount(tester);
        await tester.tap(find.text(ZhStrings().uploadPalette));
        await tester.pumpAndSettle();
        expect(target, Uri.parse('http://10.0.0.8:8088/upload'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
      () => MockClient((request) async {
        target = request.url;
        return http.Response('', 200);
      }),
    );
  });

  testWidgets('未选择设备时上传入口呈禁用状态', (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, selected: false);
    final button = find.ancestor(
      of: find.text(ZhStrings().uploadPalette),
      matching: find.byType(BouncyButton),
    );
    expect(
      tester.getSemantics(button).getSemanticsData().flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    semantics.dispose();
  });

  for (final confirm in [false, true]) {
    testWidgets('色标颜色${confirm ? '确认后保存' : '取消后保持原色'}', (tester) async {
      await mount(tester);
      await tester.tap(find.byIcon(Icons.colorize_rounded).first);
      await tester.pumpAndSettle();
      tester
          .widget<ColorPicker>(find.byType(ColorPicker))
          .onColorChanged(Colors.red);
      await tester.pump();
      await tester.tap(
        find.text(confirm ? ZhStrings().ok : ZhStrings().cancel),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.colorize_rounded).first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorPicker>(find.byType(ColorPicker)).color,
        confirm ? Colors.red : Colors.blue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('删到单个或零个色标时预览稳定，并能重新添加', (tester) async {
    await mount(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    final upload = find.ancestor(
      of: find.text(ZhStrings().uploadPalette),
      matching: find.byType(BouncyButton),
    );
    expect(tester.widget<BouncyButton>(upload).onTap, isNull);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(ZhStrings().addColorStop));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(tester.widget<BouncyButton>(upload).onTap, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
