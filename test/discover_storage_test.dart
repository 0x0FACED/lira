import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/bookmarks/data/repositories/bookmarks_local_repository.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';

void main() {
  test(
    'reading-only material stays out of Library; saving retains its progress and bookmarks',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final books = BooksLocalRepository(database);
      final now = DateTime(2026, 10, 28);
      final material = BookDto(
        id: 'source-article',
        title: 'An article',
        author: 'An author',
        format: 'epub',
        createdAt: now,
      );
      await books.saveBook(material, isSaved: false);
      final progress = ReadingProgressDto(
        bookId: material.id,
        percentage: 41.25,
        location: 'chapter:offset',
        updatedAt: now,
      );
      final bookmark = BookmarkDto(
        id: 'bookmark',
        bookId: material.id,
        location: 'chapter:offset',
        percentage: 41.25,
        createdAt: now,
      );
      await ReadingProgressLocalRepository(database).saveProgress(progress);
      await BookmarksLocalRepository(database).saveBookmark(bookmark);

      expect(await books.getAllBooks(), isEmpty);
      expect(await books.getBookById(material.id), material);
      expect(await books.isSaved(material.id), isFalse);

      await books.markSaved(material.id);
      await books.markSaved(material.id);
      expect(await books.getAllBooks(), [material]);
      expect(await books.isSaved(material.id), isTrue);
      expect(
        await ReadingProgressLocalRepository(database).getProgress(material.id),
        progress,
      );
      expect(
        await BookmarksLocalRepository(
          database,
        ).getBookmarksForBook(material.id),
        [bookmark],
      );

      await books.deleteBook(material.id);
      expect(await books.isSaved(material.id), isFalse);
      expect(await books.getBookById(material.id), isNull);
    },
  );
}
