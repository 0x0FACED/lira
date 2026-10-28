import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;

final zLibraryMirrorPreferencesProvider = Provider<SharedPreferences>(
  (ref) => sharedPrefs,
);
final zLibraryMirrorsProvider =
    StateNotifierProvider<ZLibraryMirrorsNotifier, List<String>>((ref) {
      return ZLibraryMirrorsNotifier(
        ref.watch(zLibraryMirrorPreferencesProvider),
      );
    });

class ZLibraryMirrorsNotifier extends StateNotifier<List<String>> {
  ZLibraryMirrorsNotifier(this._prefs) : super(_load(_prefs)) {
    _lastPersisted = state;
  }

  static const storageKey = 'zlibrary_approved_mirrors';
  final SharedPreferences _prefs;
  late List<String> _lastPersisted;
  Future<void> _pending = Future<void>.value();

  static List<String> _load(SharedPreferences prefs) {
    final stored = prefs.getStringList(storageKey);
    if (stored == null) return List.unmodifiable(defaultZLibraryMirrors);
    final mirrors = <String>{};
    for (final value in stored) {
      try {
        mirrors.add(normalizeZLibraryMirror(value));
      } on FormatException {
        // Invalid persisted origins must not receive session cookies.
      }
    }
    return List.unmodifiable(
      mirrors.isEmpty ? defaultZLibraryMirrors : mirrors,
    );
  }

  Future<void> setMirrors(Iterable<String> values) {
    final next = List<String>.unmodifiable(
      values.map(normalizeZLibraryMirror).toSet(),
    );
    if (next.isEmpty)
      throw const FormatException('At least one mirror is required');
    state = next;
    final write = _pending.then((_) async {
      try {
        if (!await _prefs.setStringList(storageKey, next)) {
          throw StateError('Could not save Z-Library mirrors');
        }
        _lastPersisted = next;
      } catch (_) {
        try {
          await _prefs.reload();
        } catch (_) {}
        if (mounted && identical(state, next)) state = _lastPersisted;
        rethrow;
      }
    });
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
