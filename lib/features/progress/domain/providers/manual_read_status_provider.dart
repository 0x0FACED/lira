import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../settings/data/settings_provider.dart' show sharedPrefs;

/// Local-only library status, independent of reader positions and QR sync.
final manuallyReadBookIdsProvider =
    StateNotifierProvider<ManualReadStatusNotifier, Set<String>>(
      (ref) => ManualReadStatusNotifier(sharedPrefs),
    );

final isBookManuallyReadProvider = Provider.autoDispose.family<bool, String>(
  (ref, bookId) => ref.watch(
    manuallyReadBookIdsProvider.select((bookIds) => bookIds.contains(bookId)),
  ),
);

class ManualReadStatusNotifier extends StateNotifier<Set<String>> {
  ManualReadStatusNotifier(this._prefs) : super(_load(_prefs));

  static const storageKey = 'manually_read_book_ids_v1';

  final SharedPreferences _prefs;
  Future<void> _writes = Future<void>.value();

  static Set<String> _load(SharedPreferences prefs) {
    final stored = prefs.get(storageKey);
    if (stored is! List) return const {};
    return Set<String>.unmodifiable(stored.whereType<String>());
  }

  /// Changes only the manual mark; actual completion and resume data are kept.
  /// New reader positions do not clear this mark: only an explicit unset does.
  Future<void> setRead(String bookId, bool isRead) {
    // Read and publish within the queue: failures leave the visible state
    // unchanged, and overlapping edits always build on the last durable state.
    final write = _writes.then<void>((_) async {
      if (state.contains(bookId) == isRead) return;
      final updated = {...state};
      if (isRead) {
        updated.add(bookId);
      } else {
        updated.remove(bookId);
      }
      final saved = updated.isEmpty
          ? await _prefs.remove(storageKey)
          : await _prefs.setStringList(
              storageKey,
              updated.toList(growable: false),
            );
      if (!saved) throw StateError('Could not save manual read status');
      state = Set<String>.unmodifiable(updated);
    });
    // Surface this failure to the caller without poisoning subsequent writes.
    _writes = write.catchError((Object error, StackTrace stack) {});
    return write;
  }
}
