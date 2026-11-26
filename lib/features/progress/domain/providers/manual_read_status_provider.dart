import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/stored_book_id_set_notifier.dart';
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

class ManualReadStatusNotifier extends StoredBookIdSetNotifier {
  ManualReadStatusNotifier(SharedPreferences prefs)
    : super(
        prefs,
        storageKey,
        errorMessage: 'Could not save manual read status',
      );

  static const storageKey = 'manually_read_book_ids_v1';

  /// Changes only the manual mark; actual completion and resume data are kept.
  /// New reader positions do not clear this mark: only an explicit unset does.
  Future<void> setRead(String bookId, bool isRead) => setMember(bookId, isRead);
}
