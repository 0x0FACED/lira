import 'package:injectable/injectable.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_change_tracker.dart';
import '../../domain/models/book_dto.dart';
import 'package:drift/drift.dart';

@injectable
class BooksLocalRepository {
  final AppDatabase _db;

  BooksLocalRepository(this._db);

  Future<void> saveBook(BookDto book, {bool isSaved = true}) async {
    final hash = isSaved
        ? await SyncChangeTracker.fingerprint(book.fileUrl)
        : null;
    await _db.transaction(() async {
      await _db
          .into(_db.books)
          .insertOnConflictUpdate(
            BooksCompanion.insert(
              id: book.id,
              title: book.title,
              author: Value(book.author),
              format: book.format,
              coverUrl: Value(book.coverUrl),
              fileUrl: Value(book.fileUrl),
              createdAt: book.createdAt,
              pageCount: Value(book.pageCount),
              fileSizeBytes: Value(book.fileSizeBytes),
              contentHash: Value(hash),
              isSaved: Value(isSaved),
            ),
          );
      if (isSaved && hash != null) {
        await (_db.delete(
          _db.syncExcludedBooks,
        )..where((row) => row.bookHash.equals(hash))).go();
      }
      await SyncChangeTracker(_db).captureBook(book.id);
    });
  }

  Future<void> updateBook(BookDto book) async {
    await _db.transaction(() async {
      await (_db.update(_db.books)..where((t) => t.id.equals(book.id))).write(
        BooksCompanion(title: Value(book.title), author: Value(book.author)),
      );
      await SyncChangeTracker(_db).captureBook(book.id);
    });
  }

  Future<List<BookDto>> getAllBooks() async {
    final entries = await (_db.select(
      _db.books,
    )..where((book) => book.isSaved.equals(true))).get();
    return entries
        .map(
          (e) => BookDto(
            id: e.id,
            title: e.title,
            author: e.author,
            format: e.format,
            coverUrl: e.coverUrl,
            fileUrl: e.fileUrl,
            createdAt: e.createdAt,
            pageCount: e.pageCount,
            fileSizeBytes: e.fileSizeBytes,
          ),
        )
        .toList();
  }

  Future<BookDto?> getBookById(String id) async {
    final entry = await (_db.select(
      _db.books,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null) return null;
    return BookDto(
      id: entry.id,
      title: entry.title,
      author: entry.author,
      format: entry.format,
      coverUrl: entry.coverUrl,
      fileUrl: entry.fileUrl,
      createdAt: entry.createdAt,
      pageCount: entry.pageCount,
      fileSizeBytes: entry.fileSizeBytes,
    );
  }

  Future<void> markSaved(String id) async {
    final tracker = SyncChangeTracker(_db);
    final hash = await tracker.prepareBook(id);
    await _db.transaction(() async {
      await (_db.update(_db.books)..where((book) => book.id.equals(id))).write(
        const BooksCompanion(isSaved: Value(true)),
      );
      await tracker.setBookHash(id, hash);
      if (hash != null) {
        await (_db.delete(
          _db.syncExcludedBooks,
        )..where((row) => row.bookHash.equals(hash))).go();
      }
      await tracker.captureBook(id);
    });
  }

  Future<bool> isSaved(String id) async {
    final entry = await (_db.select(
      _db.books,
    )..where((book) => book.id.equals(id))).getSingleOrNull();
    return entry?.isSaved ?? false;
  }

  Future<void> deleteBook(String id) async {
    final hash = await SyncChangeTracker(_db).prepareBook(id);
    await _db.transaction(() async {
      if (hash != null) {
        final otherCopies =
            await (_db.select(_db.books)..where(
                  (row) =>
                      row.contentHash.equals(hash) &
                      row.id.equals(id).not() &
                      row.isSaved.equals(true),
                ))
                .get();
        if (otherCopies.isEmpty) {
          await _db
              .into(_db.syncExcludedBooks)
              .insert(
                SyncExcludedBooksCompanion.insert(bookHash: hash),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
      // Keep library removal local: remove its journal, and suppress automatic
      // re-import by hash until the user explicitly saves/imports it again.
      await (_db.delete(
        _db.syncRevisions,
      )..where((row) => row.bookId.equals(id))).go();
      await (_db.delete(
        _db.readingProgresses,
      )..where((t) => t.bookId.equals(id))).go();
      await (_db.delete(
        _db.highlights,
      )..where((t) => t.bookId.equals(id))).go();
      await (_db.delete(_db.bookmarks)..where((t) => t.bookId.equals(id))).go();
      await (_db.delete(_db.books)..where((t) => t.id.equals(id))).go();
    });
  }
}
