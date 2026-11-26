import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a deduplicated set of book IDs in [SharedPreferences] with queued writes.
abstract class StoredBookIdSetNotifier extends StateNotifier<Set<String>> {
  StoredBookIdSetNotifier(this._prefs, this._storageKey, {String? errorMessage})
    : _errorMessage = errorMessage ?? 'Could not save $_storageKey',
      super(_load(_prefs, _storageKey));

  final SharedPreferences _prefs;
  final String _storageKey;
  final String _errorMessage;
  Future<void> _writes = Future<void>.value();

  static Set<String> _load(SharedPreferences prefs, String key) {
    final stored = prefs.get(key);
    if (stored is! List) return const {};
    return Set<String>.unmodifiable(stored.whereType<String>());
  }

  /// Adds or removes [bookId] and persists the change sequentially.
  Future<void> setMember(String bookId, bool included) {
    // Read and publish within the queue: failures leave the visible state
    // unchanged, and overlapping edits always build on the last durable state.
    final write = _writes.then<void>((_) async {
      if (state.contains(bookId) == included) return;
      final updated = {...state};
      if (included) {
        updated.add(bookId);
      } else {
        updated.remove(bookId);
      }
      final saved = updated.isEmpty
          ? await _prefs.remove(_storageKey)
          : await _prefs.setStringList(
              _storageKey,
              updated.toList(growable: false),
            );
      if (!saved) throw StateError(_errorMessage);
      state = Set<String>.unmodifiable(updated);
    });
    // Surface this failure to the caller without poisoning subsequent writes.
    _writes = write.catchError((Object error, StackTrace stack) {});
    return write;
  }
}
