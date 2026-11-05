import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;

final libraryColumnsProvider =
    StateNotifierProvider<LibraryColumnsNotifier, int>((ref) {
      return LibraryColumnsNotifier(sharedPrefs);
    });

class LibraryColumnsNotifier extends StateNotifier<int> {
  LibraryColumnsNotifier(this._prefs)
    : super(_prefs.getInt(storageKey) == 3 ? 3 : 2);

  static const storageKey = 'library_phone_columns';
  final SharedPreferences _prefs;

  Future<void> setColumns(int columns) async {
    assert(columns == 2 || columns == 3);
    if (state == columns) return;
    state = columns;
    await _prefs.setInt(storageKey, columns);
  }
}
