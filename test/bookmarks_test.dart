import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/bookmarks/data/repositories/bookmarks_local_repository.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/bookmarks/domain/providers/bookmarks_provider.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/highlights/data/repositories/highlights_local_repository.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';

final _createdAt = DateTime(2025, 4, 1, 12);

BookDto _book(String id) => BookDto(
  id: id,
  title: 'Book $id',
  author: 'Author $id',
  format: 'epub',
  createdAt: _createdAt,
);

BookmarkDto _bookmark(
  String id, {
  String bookId = 'book-a',
  String location = 'epubcfi(/6/14[chapter4]!/4/2:137)',
  double percentage = 58.625,
  DateTime? createdAt,
}) => BookmarkDto(
  id: id,
  bookId: bookId,
  location: location,
  percentage: percentage,
  createdAt: createdAt ?? _createdAt,
);

Future<void> _seedBooks(AppDatabase database) async {
  final books = BooksLocalRepository(database);
  await books.saveBook(_book('book-a'));
  await books.saveBook(_book('book-b'));
}

void main() {
  test(
    'opaque EPUB/PDF positions and percentages survive close and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lira-bookmarks-',
      );
      final file = File('${directory.path}/bookmarks.sqlite');
      final saved = [
        _bookmark('epub-start', percentage: 0),
        _bookmark(
          'epub-middle',
          location: 'epubcfi(/6/18[chapter5]!/4/2/6:231)',
          createdAt: _createdAt.add(const Duration(days: 1)),
        ),
        _bookmark(
          'pdf-end',
          bookId: 'book-b',
          location: '{"page":26,"x":0.25,"y":0.75}',
          percentage: 100,
        ),
      ];

      try {
        final initial = AppDatabase.forTesting(NativeDatabase(file));
        try {
          await _seedBooks(initial);
          final repository = BookmarksLocalRepository(initial);
          for (final bookmark in saved) {
            await repository.saveBookmark(bookmark);
          }
        } finally {
          await initial.close();
        }

        final reopened = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final repository = BookmarksLocalRepository(reopened);
          expect(await repository.getBookmarksForBook('book-a'), [
            saved[1],
            saved[0],
          ]);
          expect(await repository.getBookmarksForBook('book-b'), [saved[2]]);
          await repository.deleteBookmark(saved[1].id);
        } finally {
          await reopened.close();
        }

        final afterRemoval = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final repository = BookmarksLocalRepository(afterRemoval);
          expect(await repository.getBookmarksForBook('book-a'), [saved[0]]);
          expect(await repository.getBookmarksForBook('book-b'), [saved[2]]);
        } finally {
          await afterRemoval.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  group('bookmark storage', () {
    late AppDatabase database;
    late BookmarksLocalRepository repository;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = BookmarksLocalRepository(database);
      await _seedBooks(database);
    });

    tearDown(() => database.close());

    test('the same locator belongs independently to each book', () async {
      final first = _bookmark('first');
      final second = _bookmark('second', bookId: 'book-b', percentage: 12.5);
      await repository.saveBookmark(first);
      await repository.saveBookmark(second);

      expect(await repository.getBookmarksForBook('book-a'), [first]);
      expect(await repository.getBookmarksForBook('book-b'), [second]);
      expect(await repository.getBookmarksForBook('missing-book'), isEmpty);

      await repository.deleteBookmark(first.id);
      expect(await repository.getBookmarksForBook('book-a'), isEmpty);
      expect(await repository.getBookmarksForBook('book-b'), [second]);
    });

    test(
      'duplicate saves preserve the original id, date and percentage',
      () async {
        final original = _bookmark('original');
        await repository.saveBookmark(original);
        await Future.wait([
          repository.saveBookmark(
            original.copyWith(
              id: 'duplicate-a',
              percentage: 60,
              createdAt: _createdAt.add(const Duration(days: 1)),
            ),
          ),
          repository.saveBookmark(
            original.copyWith(
              id: 'duplicate-b',
              percentage: 61,
              createdAt: _createdAt.add(const Duration(days: 2)),
            ),
          ),
        ]);
        expect(await repository.getBookmarksForBook('book-a'), [original]);

        final distinct = original.copyWith(
          id: 'next-position',
          location: '${original.location}/1',
        );
        await repository.saveBookmark(distinct);
        expect(
          await repository.getBookmarksForBook('book-a'),
          unorderedEquals([original, distinct]),
        );
      },
    );

    test(
      'the database rejects duplicate book/location outside the repository',
      () async {
        final original = _bookmark('original');
        await repository.saveBookmark(original);
        await expectLater(
          database
              .into(database.bookmarks)
              .insert(
                BookmarksCompanion.insert(
                  id: 'duplicate',
                  bookId: original.bookId,
                  location: original.location,
                  percentage: 90,
                  createdAt: _createdAt,
                ),
              ),
          throwsException,
        );
        expect(await repository.getBookmarksForBook('book-a'), [original]);
      },
    );

    test(
      'an id collision at a different location is not silently ignored',
      () async {
        final original = _bookmark('same-id');
        await repository.saveBookmark(original);
        await expectLater(
          repository.saveBookmark(
            original.copyWith(location: 'another-position'),
          ),
          throwsException,
        );
        expect(await repository.getBookmarksForBook('book-a'), [original]);
      },
    );

    test(
      'removal affects only the requested bookmark and allows adding it again',
      () async {
        final first = _bookmark('first');
        final second = _bookmark('second', location: 'another-position');
        await repository.saveBookmark(first);
        await repository.saveBookmark(second);

        await repository.deleteBookmark(first.id);
        await repository.deleteBookmark('missing-id');
        expect(await repository.getBookmarksForBook('book-a'), [second]);

        final addedAgain = first.copyWith(id: 'new-id');
        await repository.saveBookmark(addedAgain);
        expect(
          await repository.getBookmarksForBook('book-a'),
          unorderedEquals([second, addedAgain]),
        );
      },
    );

    test(
      'book deletion removes its bookmarks without changing other books',
      () async {
        final first = _bookmark('first');
        final second = _bookmark('second', bookId: 'book-b');
        await repository.saveBookmark(first);
        await repository.saveBookmark(second);

        await BooksLocalRepository(database).deleteBook('book-a');

        expect(
          await BooksLocalRepository(database).getBookById('book-a'),
          isNull,
        );
        expect(await repository.getBookmarksForBook('book-a'), isEmpty);
        expect(await repository.getBookmarksForBook('book-b'), [second]);
        expect(
          await BooksLocalRepository(database).getBookById('book-b'),
          _book('book-b'),
        );
      },
    );

    test(
      'failed book deletion rolls bookmark cleanup back atomically',
      () async {
        final bookmark = _bookmark('retained');
        await repository.saveBookmark(bookmark);
        await database.customStatement('''
        CREATE TRIGGER prevent_book_delete BEFORE DELETE ON books
        WHEN OLD.id = 'book-a'
        BEGIN
          SELECT RAISE(ABORT, 'book deletion blocked');
        END
      ''');

        await expectLater(
          BooksLocalRepository(database).deleteBook('book-a'),
          throwsException,
        );
        expect(
          await BooksLocalRepository(database).getBookById('book-a'),
          _book('book-a'),
        );
        expect(await repository.getBookmarksForBook('book-a'), [bookmark]);
      },
    );
  });

  test(
    'v2 upgrade preserves books, progress and highlights and adds durable bookmarks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lira-bookmarks-v2-',
      );
      final file = File('${directory.path}/library.sqlite');
      final book = _book('legacy-book').copyWith(
        title: 'Legacy title',
        author: 'Legacy author',
        coverUrl: '/covers/legacy.jpg',
        fileUrl: '/books/legacy.epub',
        pageCount: 345,
        fileSizeBytes: 1234567,
      );
      final progress = ReadingProgressDto(
        bookId: book.id,
        percentage: 74.125,
        location: 'epubcfi(/6/24!/4/8:99)',
        updatedAt: _createdAt.add(const Duration(hours: 1)),
      );
      final highlight = HighlightDto(
        id: 'legacy-highlight',
        bookId: book.id,
        text: 'Keep the highlighted passage',
        color: '#123456',
        location: 'epubcfi(/6/24!/4/8:12)',
        note: 'Keep the note as well',
        createdAt: _createdAt.add(const Duration(hours: 2)),
      );
      final bookmark = _bookmark(
        'new-bookmark',
        bookId: book.id,
        location: progress.location,
        percentage: progress.percentage,
      );

      try {
        final legacy = _Version2Database(NativeDatabase(file));
        try {
          await legacy.customStatement(
            'INSERT INTO books (id, title, author, format, cover_url, file_url, '
            'created_at, page_count, file_size_bytes, content_hash) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              book.id,
              book.title,
              book.author,
              book.format,
              book.coverUrl,
              book.fileUrl,
              book.createdAt.millisecondsSinceEpoch ~/ 1000,
              book.pageCount,
              book.fileSizeBytes,
              'legacy-content-hash',
            ],
          );
          await ReadingProgressLocalRepository(legacy).saveProgress(progress);
          await HighlightsLocalRepository(legacy).saveHighlight(highlight);
        } finally {
          await legacy.close();
        }

        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(await BooksLocalRepository(upgraded).getAllBooks(), [book]);
          expect(
            await ReadingProgressLocalRepository(upgraded).getProgress(book.id),
            progress,
          );
          expect(
            await HighlightsLocalRepository(
              upgraded,
            ).getHighlightsForBook(book.id),
            [highlight],
          );
          final storedBook = await upgraded.select(upgraded.books).getSingle();
          expect(storedBook.contentHash, 'legacy-content-hash');
          final bookmarks = BookmarksLocalRepository(upgraded);
          expect(await bookmarks.getBookmarksForBook(book.id), isEmpty);
          await bookmarks.saveBookmark(bookmark);
        } finally {
          await upgraded.close();
        }

        final reopened = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(
            await BookmarksLocalRepository(
              reopened,
            ).getBookmarksForBook(book.id),
            [bookmark],
          );
          expect(await BooksLocalRepository(reopened).getAllBooks(), [book]);
          expect(
            await ReadingProgressLocalRepository(reopened).getProgress(book.id),
            progress,
          );
          expect(
            await HighlightsLocalRepository(
              reopened,
            ).getHighlightsForBook(book.id),
            [highlight],
          );
        } finally {
          await reopened.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  group('bookmarks controller', () {
    late AppDatabase database;
    late BookmarksLocalRepository repository;
    late ProviderContainer container;
    late BookmarksController controller;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = BookmarksLocalRepository(database);
      await _seedBooks(database);
      getIt.registerSingleton<BookmarksLocalRepository>(repository);
      container = ProviderContainer();
      await container.read(bookmarksControllerProvider('book-a').future);
      controller = container.read(
        bookmarksControllerProvider('book-a').notifier,
      );
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
      await database.close();
    });

    test(
      'add/remove refresh persisted state without duplicate positions',
      () async {
        await controller.addBookmark(
          location: 'reader-position',
          percentage: 42.75,
        );
        final first = container
            .read(bookmarksControllerProvider('book-a'))
            .requireValue
            .single;
        expect(first.location, 'reader-position');
        expect(first.percentage, 42.75);
        await controller.addBookmark(
          location: 'reader-position',
          percentage: 43,
        );
        expect(
          container.read(bookmarksControllerProvider('book-a')).requireValue,
          [first],
        );
        expect(await repository.getBookmarksForBook('book-a'), [first]);
        expect(
          await container.read(bookmarksControllerProvider('book-b').future),
          isEmpty,
        );

        await controller.removeBookmark(first.id);
        expect(
          container.read(bookmarksControllerProvider('book-a')).requireValue,
          isEmpty,
        );
        expect(await repository.getBookmarksForBook('book-a'), isEmpty);
      },
    );

    test(
      'failed additions propagate the storage error and retain existing state',
      () async {
        await controller.addBookmark(
          location: 'saved-position',
          percentage: 10,
        );
        final before = container
            .read(bookmarksControllerProvider('book-a'))
            .requireValue;
        await database.customStatement('''
        CREATE TRIGGER prevent_bookmark_insert BEFORE INSERT ON bookmarks
        BEGIN
          SELECT RAISE(ABORT, 'bookmark insertion blocked');
        END
      ''');

        await expectLater(
          controller.addBookmark(location: 'unsaved-position', percentage: 20),
          throwsException,
        );
        expect(
          container.read(bookmarksControllerProvider('book-a')).requireValue,
          before,
        );
        expect(await repository.getBookmarksForBook('book-a'), before);
      },
    );

    test(
      'failed removals propagate the storage error and retain existing state',
      () async {
        await controller.addBookmark(
          location: 'saved-position',
          percentage: 10,
        );
        final before = container
            .read(bookmarksControllerProvider('book-a'))
            .requireValue;
        await database.customStatement('''
        CREATE TRIGGER prevent_bookmark_delete BEFORE DELETE ON bookmarks
        BEGIN
          SELECT RAISE(ABORT, 'bookmark deletion blocked');
        END
      ''');

        await expectLater(
          controller.removeBookmark(before.single.id),
          throwsException,
        );
        expect(
          container.read(bookmarksControllerProvider('book-a')).requireValue,
          before,
        );
        expect(await repository.getBookmarksForBook('book-a'), before);
      },
    );
  });
}

// Frozen v2 schema: do not derive this fixture from the evolving table set.
class _Version2Database extends AppDatabase {
  _Version2Database(QueryExecutor executor) : super.forTesting(executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
        CREATE TABLE books (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT NOT NULL DEFAULT 'Unknown Author',
          format TEXT NOT NULL,
          cover_url TEXT,
          file_url TEXT,
          created_at INTEGER NOT NULL,
          page_count INTEGER NOT NULL DEFAULT 0,
          file_size_bytes INTEGER NOT NULL DEFAULT 0,
          content_hash TEXT
        )
      ''');
      await customStatement('''
        CREATE TABLE reading_progresses (
          book_id TEXT NOT NULL PRIMARY KEY REFERENCES books (id),
          percentage REAL NOT NULL,
          location TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE highlights (
          id TEXT NOT NULL PRIMARY KEY,
          book_id TEXT NOT NULL REFERENCES books (id),
          text_content TEXT NOT NULL,
          color TEXT NOT NULL DEFAULT '#BB86FC',
          location TEXT NOT NULL,
          note TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    },
  );
}
