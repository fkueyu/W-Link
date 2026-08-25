import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flux/providers/quick_color_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('replacing a quick color survives creating a new notifier', () async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = QuickColorPaletteNotifier(prefs);

    await notifier.replace(2, const Color(0xFF123456));
    final restored = QuickColorPaletteNotifier(prefs);

    expect(restored.state[2].toARGB32(), 0xFF123456);
    expect(restored.state.length, QuickColorPaletteNotifier.defaults.length);
  });

  test('malformed stored colors fall back to the curated palette', () async {
    SharedPreferences.setMockInitialValues({
      QuickColorPaletteNotifier.storageKey: <String>['oops', '-1'],
    });
    final prefs = await SharedPreferences.getInstance();

    final notifier = QuickColorPaletteNotifier(prefs);

    expect(
      notifier.state.map((color) => color.toARGB32()),
      QuickColorPaletteNotifier.defaults.map((color) => color.toARGB32()),
    );
  });
}
