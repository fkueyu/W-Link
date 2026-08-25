import 'dart:ui' as ui;

import 'package:flux/widgets/bouncy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes an enabled labeled button to assistive technology', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyButton(
            semanticLabel: '打开设备',
            onTap: () {},
            child: const Icon(Icons.lightbulb_outline),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('打开设备'));
    final flags = node.getSemanticsData().flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isEnabled, ui.Tristate.isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('supports tab focus and enter or space activation', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var activationCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyButton(
            focusNode: focusNode,
            onTap: () => activationCount++,
            child: const Text('切换灯光'),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final focusContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(BouncyButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final focusDecoration = focusContainer.decoration! as BoxDecoration;
    expect(focusDecoration.border!.top.color, const Color(0xFFAF47FF));
    expect(focusDecoration.border!.top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(activationCount, 2);
  });

  testWidgets('disabled button exposes no tap action and takes no focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyButton(
            semanticLabel: '不可用操作',
            focusNode: focusNode,
            child: const Text('不可用'),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final node = tester.getSemantics(find.byType(BouncyButton));
    expect(node.label, '不可用操作');
    expect(
      node.getSemanticsData().flagsCollection.isEnabled,
      ui.Tristate.isFalse,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(focusNode.hasFocus, isFalse);
    semantics.dispose();
  });

  testWidgets('long-press-only button exposes no keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var longPressCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BouncyButton(
            semanticLabel: '保存颜色',
            focusNode: focusNode,
            onLongPress: () => longPressCount++,
            child: const Text('保存颜色'),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(BouncyButton));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(focusNode.hasFocus, isFalse);
    expect(longPressCount, 0);

    await tester.longPress(find.byType(BouncyButton));
    expect(longPressCount, 1);
    semantics.dispose();
  });
}
