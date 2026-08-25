import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common_providers.dart';

final quickColorPaletteProvider =
    StateNotifierProvider<QuickColorPaletteNotifier, List<Color>>((ref) {
      return QuickColorPaletteNotifier(ref.watch(sharedPreferencesProvider));
    });

class QuickColorPaletteNotifier extends StateNotifier<List<Color>> {
  static const storageKey = 'wlink_quick_colors';

  static const defaults = <Color>[
    Color(0xFFFF3B30),
    Color(0xFFFF8A34),
    Color(0xFFFFD60A),
    Color(0xFF34C759),
    Color(0xFF2DD4BF),
    Color(0xFF32ADE6),
    Color(0xFF0A84FF),
    Color(0xFF5E5CE6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D8D),
    Color(0xFFFFFFFF),
  ];

  final SharedPreferences _prefs;

  QuickColorPaletteNotifier(this._prefs) : super(_restore(_prefs));

  Future<void> replace(int index, Color color) async {
    RangeError.checkValidIndex(index, state, 'index');
    final next = [...state]..[index] = color;
    state = List.unmodifiable(next);
    await _prefs.setStringList(
      storageKey,
      next.map((item) => item.toARGB32().toUnsigned(32).toString()).toList(),
    );
  }

  Future<void> reset() async {
    state = defaults;
    await _prefs.remove(storageKey);
  }

  static List<Color> _restore(SharedPreferences prefs) {
    final stored = prefs.getStringList(storageKey);
    if (stored == null || stored.length != defaults.length) return defaults;

    final values = <Color>[];
    for (final raw in stored) {
      final value = int.tryParse(raw);
      if (value == null || value < 0 || value > 0xFFFFFFFF) return defaults;
      values.add(Color(value));
    }
    return List.unmodifiable(values);
  }
}
