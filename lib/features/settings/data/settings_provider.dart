import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

/// Pre-loaded SharedPreferences instance, set in main() before runApp.
late final SharedPreferences sharedPrefs;

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
      return ReaderSettingsNotifier(sharedPrefs);
    });

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  static const _settingsKey = 'reader_settings';
  static final _defaultSettings = ReaderSettings(
    backgroundColor: AppTheme.paperColor.toARGB32(),
  );
  final SharedPreferences _prefs;

  ReaderSettingsNotifier(this._prefs) : super(_loadInitial(_prefs));

  static ReaderSettings _loadInitial(SharedPreferences prefs) {
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        return ReaderSettings.fromJson(jsonDecode(settingsJson));
      } catch (_) {
        // Corrupted settings — fall back to defaults
      }
    }
    return _defaultSettings;
  }

  Future<void> updateSettings(ReaderSettings newSettings) async {
    await _prefs.setString(_settingsKey, jsonEncode(newSettings.toJson()));
    state = newSettings;
  }

  void resetSettings() {
    updateSettings(_defaultSettings);
  }
}
