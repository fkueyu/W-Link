import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/quick_color_provider.dart';
import 'package:flux/widgets/color_picker_sheet.dart';

void main() {
  testWidgets(
    'quick color taps render immediately but send only first and latest',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final firstSend = Completer<void>();
      final sent = <Color>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: MaterialApp(
            home: Scaffold(
              body: ColorPickerSheet(
                initialColor: Colors.black,
                onColorChanged: (color) async {
                  sent.add(color);
                  if (sent.length == 1) await firstSend.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('quick-color-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quick-color-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quick-color-2')));
      await tester.pump();

      expect(sent, [QuickColorPaletteNotifier.defaults[0]]);
      expect(find.byIcon(Icons.check), findsOneWidget);

      firstSend.complete();
      await tester.pumpAndSettle();
      expect(sent, [
        QuickColorPaletteNotifier.defaults[0],
        QuickColorPaletteNotifier.defaults[2],
      ]);
    },
  );
}
