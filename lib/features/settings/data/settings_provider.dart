import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_engine/epub_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
      return ReaderSettingsNotifier();
    });

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  static const _settingsKey = 'reader_settings';
  late final SharedPreferences _prefs;

  ReaderSettingsNotifier() : super(const ReaderSettings()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      state = ReaderSettings.fromJson(jsonDecode(settingsJson));
    }
  }

  Future<void> updateSettings(ReaderSettings newSettings) async {
    await _prefs.setString(_settingsKey, jsonEncode(newSettings.toJson()));
    state = newSettings;
  }

  void resetSettings() {
    updateSettings(const ReaderSettings());
  }
}
