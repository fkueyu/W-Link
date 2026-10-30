import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flux/core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flux/providers/common_providers.dart';
import 'package:flux/providers/quick_color_provider.dart';
import 'package:flux/widgets/color_picker_sheet.dart';

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required Future<void> Function(Color) onChanged,
    Color initialColor = Colors.black,
    Size size = const Size(382, 644),
    double textScale = 1,
    bool modal = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Widget picker() =>
        ColorPickerSheet(initialColor: initialColor, onColorChanged: onChanged);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          l10nProvider.overrideWithValue(ZhStrings()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: modal
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => picker(),
                      ),
                      child: const Text('打开色盘'),
                    ),
                  )
                : picker(),
          ),
        ),
      ),
    );
    if (modal) {
      await tester.tap(find.text('打开色盘'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'HEX accepts optional hash and either case, and updates the selected color',
    (tester) async {
      final sent = <Color>[];
      await pumpPicker(tester, onChanged: (color) async => sent.add(color));
      final field = find.byKey(const ValueKey('color-hex-input'));
      expect(field, findsOneWidget);
      await tester.enterText(field, '#12aBcD');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent, [const Color(0xFF12ABCD)]);
      expect(tester.widget<TextField>(field).controller!.text, '#12ABCD');
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('color-wheel')))
            .getSemanticsData()
            .value,
        '#12ABCD',
      );
      await tester.enterText(field, 'ff3b30');
      await tester.tap(find.byTooltip('应用颜色'));
      await tester.pumpAndSettle();
      expect(sent.last, const Color(0xFFFF3B30));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('quick-color-0')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    },
  );

  testWidgets(
    'invalid HEX gives feedback without sending a color, and can be corrected',
    (tester) async {
      final sent = <Color>[];
      await pumpPicker(tester, onChanged: (color) async => sent.add(color));
      final field = find.byKey(const ValueKey('color-hex-input'));
      expect(field, findsOneWidget);
      for (final invalid in ['', '#123', 'GG0011', '#12345678']) {
        await tester.enterText(field, invalid);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(sent, isEmpty);
        expect(
          tester.widget<TextField>(field).decoration!.errorText,
          isNotNull,
        );
      }
      await tester.enterText(field, '001122');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(sent, [const Color(0xFF001122)]);
      expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
    },
  );

  testWidgets(
    'quick colors expose selected value and a 44pt touch target including its edge',
    (tester) async {
      final sent = <Color>[];
      await pumpPicker(
        tester,
        initialColor: const Color(0xFFFF3B30),
        onChanged: (color) async => sent.add(color),
      );
      final first = find.byKey(const ValueKey('quick-color-0'));
      final second = find.byKey(const ValueKey('quick-color-1'));
      final selected = tester.getSemantics(first).getSemanticsData();
      expect(selected.flagsCollection.isButton, isTrue);
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(selected.value, '#FF3B30');
      expect(selected.hasAction(SemanticsAction.tap), isTrue);
      expect(selected.hasAction(SemanticsAction.longPress), isTrue);
      final rect = tester.getRect(second);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
      await tester.pumpAndSettle();
      expect(sent, [const Color(0xFFFF8A34)]);
      expect(
        tester
            .getSemantics(second)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(first)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
    },
  );

  testWidgets(
    'quick colors can be reached with Tab and activated with Enter and Space',
    (tester) async {
      final sent = <Color>[];
      await pumpPicker(tester, onChanged: (color) async => sent.add(color));
      // HEX, its apply button, explicit replace, then the first quick color.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(sent, [const Color(0xFFFF3B30)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(sent.last, const Color(0xFFFF8A34));
    },
  );

  testWidgets('键盘显式替换快捷色，说明当前HEX并持久化选定槽位', (tester) async {
    final sent = <Color>[];
    await pumpPicker(
      tester,
      initialColor: const Color(0xFF123456),
      onChanged: (color) async => sent.add(color),
    );
    expect(find.text('替换快捷色'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('替换快捷色'),
              matching: find.byType(TextButton),
            ),
          )
          .height,
      greaterThanOrEqualTo(44),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('#123456'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(QuickColorPaletteNotifier.storageKey)!.first,
      '4279383126',
    );
    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(
      restored.read(quickColorPaletteProvider).first,
      const Color(0xFF123456),
    );
    restored.dispose();
    expect(sent, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('long press still saves the current HEX color in a quick slot', (
    tester,
  ) async {
    await pumpPicker(tester, onChanged: (_) async {});
    final field = find.byKey(const ValueKey('color-hex-input'));
    expect(field, findsOneWidget);
    await tester.enterText(field, '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('quick-color-0')));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(QuickColorPaletteNotifier.storageKey)!.first,
      '4279383126',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  for (final size in [const Size(382, 644), const Size(480, 600)]) {
    testWidgets('wheel, HEX and quick colors fit without scrolling at $size', (
      tester,
    ) async {
      await pumpPicker(tester, onChanged: (_) async {}, size: size);
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.byKey(const ValueKey('color-hex-input'))).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('quick-color-0'))).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'HEX remains visible and content scrolls above a tall keyboard at text scale $scale',
      (tester) async {
        await pumpPicker(
          tester,
          onChanged: (_) async {},
          size: const Size(480, 600),
          textScale: scale,
          modal: true,
        );
        final field = find.byKey(const ValueKey('color-hex-input'));
        expect(field, findsOneWidget);
        await tester.tap(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 400);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(field).bottom, lessThanOrEqualTo(200));
        expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await tester.enterText(field, 'abcdef');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

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
