import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/stored_book_id_set_notifier.dart';
import '../../../settings/data/settings_provider.dart' show sharedPrefs;

/// Local-only favorite books set, independent of reader positions and QR sync.
final favoriteBookIdsProvider =
    StateNotifierProvider<FavoriteBooksNotifier, Set<String>>(
      (ref) => FavoriteBooksNotifier(sharedPrefs),
    );

final isBookFavoriteProvider = Provider.autoDispose.family<bool, String>(
  (ref, bookId) => ref.watch(
    favoriteBookIdsProvider.select((bookIds) => bookIds.contains(bookId)),
  ),
);

/// Stores favorite book IDs in [SharedPreferences].
class FavoriteBooksNotifier extends StoredBookIdSetNotifier {
  FavoriteBooksNotifier(SharedPreferences prefs)
    : super(prefs, storageKey, errorMessage: 'Could not save favorite books');

  static const storageKey = 'favorite_book_ids_v1';

  /// Marks or unmarks [bookId] as a favorite.
  Future<void> setFavorite(String bookId, bool isFavorite) =>
      setMember(bookId, isFavorite);
}
