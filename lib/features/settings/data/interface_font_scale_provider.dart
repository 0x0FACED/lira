import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_provider.dart' show sharedPrefs;

const interfaceFontScaleOptions = [80, 90, 100, 110, 120, 130, 140];

final interfaceFontScaleProvider =
    StateNotifierProvider<InterfaceFontScaleNotifier, int>((ref) {
      return InterfaceFontScaleNotifier(sharedPrefs);
    });

class InterfaceFontScaleNotifier extends StateNotifier<int> {
  InterfaceFontScaleNotifier(this._prefs) : super(_load(_prefs));

  static const storageKey = 'interface_font_scale_percent';
  final SharedPreferences _prefs;

  static int _load(SharedPreferences prefs) {
    final percent = prefs.getInt(storageKey);
    return interfaceFontScaleOptions.contains(percent) ? percent! : 100;
  }

  Future<void> setPercent(int percent) async {
    assert(interfaceFontScaleOptions.contains(percent));
    if (state == percent) return;
    state = percent;
    await _prefs.setInt(storageKey, percent);
  }
}
