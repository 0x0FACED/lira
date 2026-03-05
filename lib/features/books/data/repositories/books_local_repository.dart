import 'package:injectable/injectable.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/book_dto.dart';
import 'package:drift/drift.dart';

@injectable
class BooksLocalRepository {
  final AppDatabase _db;

  BooksLocalRepository(this._db);

  Future<void> saveBook(BookDto book) async {
    await _db
        .into(_db.books)
        .insert(
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
          ),
          mode: InsertMode.replace,
        );
  }

  Future<void> updateBook(BookDto book) async {
    await (_db.update(_db.books)..where((t) => t.id.equals(book.id))).write(
      BooksCompanion(title: Value(book.title), author: Value(book.author)),
    );
  }

  Future<List<BookDto>> getAllBooks() async {
    final entries = await _db.select(_db.books).get();
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

  Future<void> deleteBook(String id) async {
    await (_db.delete(_db.books)..where((t) => t.id.equals(id))).go();
  }
}
