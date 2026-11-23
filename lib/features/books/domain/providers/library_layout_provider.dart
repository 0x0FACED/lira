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

enum LibrarySort { added, recent, progress, title, author }

final librarySortProvider =
    StateNotifierProvider<LibrarySortNotifier, LibrarySort>((ref) {
      return LibrarySortNotifier(sharedPrefs);
    });

class LibrarySortNotifier extends StateNotifier<LibrarySort> {
  LibrarySortNotifier(this._prefs)
    : super(
        LibrarySort.values.firstWhere(
          (sort) => sort.name == _prefs.getString(_storageKey),
          orElse: () => LibrarySort.added,
        ),
      );

  static const _storageKey = 'library_sort';
  final SharedPreferences _prefs;

  Future<void> setSort(LibrarySort sort) async {
    if (state == sort) return;
    state = sort;
    await _prefs.setString(_storageKey, sort.name);
  }
}

final libraryListViewProvider =
    StateNotifierProvider<LibraryListViewNotifier, bool>((ref) {
      return LibraryListViewNotifier(sharedPrefs);
    });

class LibraryListViewNotifier extends StateNotifier<bool> {
  LibraryListViewNotifier(this._prefs)
    : super(_prefs.getBool(_storageKey) ?? false);

  static const _storageKey = 'library_list_view';
  final SharedPreferences _prefs;

  Future<void> setListView(bool value) async {
    if (state == value) return;
    state = value;
    await _prefs.setBool(_storageKey, value);
  }
}
