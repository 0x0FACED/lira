import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/bookmark_dto.dart';

@injectable
class BookmarksLocalRepository {
  final AppDatabase _db;

  BookmarksLocalRepository(this._db);

  Future<List<BookmarkDto>> getBookmarksForBook(String bookId) async {
    final query = _db.select(_db.bookmarks)
      ..where((t) => t.bookId.equals(bookId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    final entries = await query.get();
    return entries
        .map(
          (e) => BookmarkDto(
            id: e.id,
            bookId: e.bookId,
            location: e.location,
            percentage: e.percentage,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }

  Future<void> saveBookmark(BookmarkDto bookmark) async {
    await _db
        .into(_db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: bookmark.id,
            bookId: bookmark.bookId,
            location: bookmark.location,
            percentage: bookmark.percentage,
            createdAt: bookmark.createdAt,
          ),
          onConflict: DoNothing(
            target: [_db.bookmarks.bookId, _db.bookmarks.location],
          ),
        );
  }

  Future<void> deleteBookmark(String id) async {
    await (_db.delete(_db.bookmarks)..where((t) => t.id.equals(id))).go();
  }
}
