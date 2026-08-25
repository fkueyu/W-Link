import 'dart:ui' as ui;

import 'package:flux/core/l10n.dart';
import 'package:flux/models/wled_state.dart';
import 'package:flux/widgets/nightlight_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('off editor hides parameters and preserves them when enabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    WledNightlight? changed;
    final strings = ZhStrings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NightlightEditor(
              value: const WledNightlight(
                on: false,
                dur: 45,
                mode: 2,
                tbri: 32,
              ),
              strings: strings,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    final switchSemantics = tester
        .getSemantics(find.byType(Switch))
        .getSemanticsData();
    expect(switchSemantics.label, strings.nightlight);
    expect(switchSemantics.flagsCollection.isToggled, ui.Tristate.isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(changed?.on, isTrue);
    expect(changed?.dur, 45);
    expect(changed?.mode, 2);
    expect(changed?.tbri, 32);
    semantics.dispose();
  });

  testWidgets('active editor exposes parameters and changes only the mode', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    WledNightlight? changed;
    final strings = ZhStrings();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NightlightEditor(
              value: const WledNightlight(on: true, dur: 45, mode: 1, tbri: 32),
              strings: strings,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsNWidgets(2));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(strings.modeFade))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );

    await tester.ensureVisible(find.text(strings.modeSunrise));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.modeSunrise));
    await tester.pump();

    expect(changed?.on, isTrue);
    expect(changed?.dur, 45);
    expect(changed?.mode, 3);
    expect(changed?.tbri, 32);
    semantics.dispose();
  });

  testWidgets('summary card navigates without duplicating editor controls', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NightlightSummaryCard(
            value: const WledNightlight(on: true),
            strings: ZhStrings(),
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    expect(find.text(ZhStrings().nightlight), findsOneWidget);
    expect(find.text('定时进行中'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.byType(NightlightSummaryCard));
    expect(tapCount, 1);
  });
}
