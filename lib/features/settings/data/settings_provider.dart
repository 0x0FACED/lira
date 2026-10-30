import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
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

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings>
    with WidgetsBindingObserver {
  static const _settingsKey = 'reader_settings';
  static final _defaultSettings = ReaderSettings(
    backgroundColor: AppTheme.paperColor.toARGB32(),
  );
  final SharedPreferences _prefs;
  Timer? _saveTimer;
  ReaderSettings? _pendingSettings;
  Future<void> _writes = Future<void>.value();

  ReaderSettingsNotifier(this._prefs) : super(_loadInitial(_prefs)) {
    WidgetsBinding.instance.addObserver(this);
  }

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
    if (state == newSettings) return;
    state = newSettings;
    _pendingSettings = newSettings;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 200), _saveInBackground);
  }

  /// Applies slider changes immediately; only persistence is debounced.
  Future<void> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _pendingSettings;
    if (pending == null) return _writes;
    _pendingSettings = null;
    final write = _writes.then<void>((_) async {
      final saved = await _prefs.setString(
        _settingsKey,
        jsonEncode(pending.toJson()),
      );
      if (!saved) throw StateError('Could not save reader settings');
    });
    // Keep subsequent saves usable after an earlier write failed.
    _writes = write.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Lira reader settings',
          context: ErrorDescription('while saving reader settings'),
        ),
      );
    });
    return write;
  }

  void _saveInBackground() {
    unawaited(flush().catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _saveInBackground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveInBackground();
    super.dispose();
  }

  void resetSettings() {
    updateSettings(_defaultSettings);
  }
}
