import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/settings_provider.dart' show sharedPrefs;
import 'discover_source.dart';

final discoverCatalogProvider = Provider<List<DiscoverSource>>(
  (ref) => discoverSourceCatalog,
);
final discoverPreferencesProvider = Provider<SharedPreferences>(
  (ref) => sharedPrefs,
);

final selectedDiscoverSourcesProvider =
    StateNotifierProvider<DiscoverSourcesNotifier, List<String>>((ref) {
      return DiscoverSourcesNotifier(ref.watch(discoverPreferencesProvider));
    });

final enabledDiscoverSourcesProvider = Provider<List<DiscoverSource>>((ref) {
  final catalog = {
    for (final source in ref.watch(discoverCatalogProvider)) source.id: source,
  };
  return [
    for (final id in ref.watch(selectedDiscoverSourcesProvider))
      if (catalog[id] case final source?) source,
  ];
});

class DiscoverSourcesNotifier extends StateNotifier<List<String>> {
  DiscoverSourcesNotifier(this._prefs) : super(_load(_prefs)) {
    _lastPersisted = state;
  }

  static const storageKey = 'discover_selected_sources';
  final SharedPreferences _prefs;
  Future<void> _pendingWrite = Future<void>.value();
  late List<String> _lastPersisted;

  static List<String> _load(SharedPreferences prefs) {
    final saved = prefs.getStringList(storageKey);
    if (saved != null) return List.unmodifiable(saved.toSet());
    final legacy = prefs.getString('pref_search_source');
    return List.unmodifiable([
      DiscoverSourceIds.cloudflare,
      DiscoverSourceIds.github,
      DiscoverSourceIds.rfc,
      if (legacy != 'zlibrary') DiscoverSourceIds.anna,
      if (legacy == 'zlibrary' || legacy == 'both') DiscoverSourceIds.zlibrary,
    ]);
  }

  Future<void> setEnabled(String id, bool enabled) {
    if (state.contains(id) == enabled) return _persist();
    state = List.unmodifiable(
      enabled ? [...state, id] : state.where((value) => value != id),
    );
    return _persist();
  }

  Future<void> move(String id, int offset) {
    final from = state.indexOf(id);
    final to = from + offset;
    if (from < 0 || to < 0 || to >= state.length) return _pendingWrite;
    final next = [...state];
    next.removeAt(from);
    next.insert(to, id);
    state = List.unmodifiable(next);
    return _persist();
  }

  Future<void> _persist() {
    final snapshot = state;
    final write = _pendingWrite.then((_) async {
      try {
        if (!await _prefs.setStringList(storageKey, snapshot)) {
          throw StateError('Could not save source selection');
        }
        _lastPersisted = snapshot;
        await _prefs.remove('pref_search_source');
      } catch (_) {
        // SharedPreferences updates its in-memory cache before a disk write.
        // Reload it too, so reopening the manager cannot resurrect a failed edit.
        try {
          await _prefs.reload();
        } catch (_) {
          // Preserve the write failure and the last known committed selection.
        }
        if (mounted && identical(state, snapshot)) state = _lastPersisted;
        rethrow;
      }
    });
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return write;
  }
}
