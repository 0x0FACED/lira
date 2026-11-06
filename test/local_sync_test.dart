import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/bookmarks/domain/providers/bookmarks_provider.dart';
import 'package:lira/features/highlights/domain/providers/highlights_provider.dart';
import 'package:lira/features/progress/domain/providers/reading_progress_provider.dart';
import 'package:lira/core/database/app_database.dart';
import 'package:lira/features/bookmarks/data/repositories/bookmarks_local_repository.dart';
import 'package:lira/features/bookmarks/domain/models/bookmark_dto.dart';
import 'package:lira/features/books/data/repositories/books_local_repository.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/highlights/data/repositories/highlights_local_repository.dart';
import 'package:lira/features/highlights/domain/models/highlight_dto.dart';
import 'package:lira/features/local_sync/data/local_sync_service.dart';
import 'package:lira/features/local_sync/data/local_sync_store.dart';
import 'package:lira/features/local_sync/domain/sync_models.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';

const _locator = '{"v":2,"c":10,"s":0}';

class _Library {
  _Library(this.directory, {bool persistent = false})
    : database = AppDatabase.forTesting(
        persistent
            ? NativeDatabase(File('${directory.path}/library.sqlite'))
            : NativeDatabase.memory(),
      );
  final Directory directory;
  final AppDatabase database;
  late final books = BooksLocalRepository(database);
  late final highlights = HighlightsLocalRepository(database);
  late final bookmarks = BookmarksLocalRepository(database);
  late final progress = ReadingProgressLocalRepository(database);
  late final store = LocalSyncStore(database: database, directory: directory);

  Future<BookDto> import(
    String id,
    List<int> bytes, {
    bool saved = true,
  }) async {
    final file = await File('${directory.path}/$id.epub').writeAsBytes(bytes);
    final book = BookDto(
      id: id,
      title: 'Book $id',
      author: 'Reader',
      format: 'epub',
      createdAt: DateTime.utc(2026),
      fileUrl: file.path,
      fileSizeBytes: bytes.length,
    );
    await books.saveBook(book, isSaved: saved);
    return book;
  }

  Future<SyncMergeResult> receive(_Library peer) async => store.merge(
    await peer.store.snapshot(),
    fetchBook: (hash) async {
      final source = await peer.store.bookFile(hash);
      if (source == null) throw StateError('Missing source $hash');
      return source.copy('${directory.path}/incoming-$hash');
    },
  );
}

List<int> _epub(String text, {bool large = false}) {
  final files = {
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    'content.opf':
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Book</dc:title><dc:creator>Reader</dc:creator></metadata><manifest><item id="text" href="text.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="text"/></spine></package>',
    'text.xhtml':
        '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>$text</p></body></html>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  if (large) {
    final random = Random(42);
    final padding = List<int>.generate(180000, (_) => random.nextInt(256));
    archive.addFile(ArchiveFile('padding.bin', padding.length, padding));
  }
  return ZipEncoder().encode(archive)!;
}

Future<void> _waitFor(bool Function() predicate) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('Sync transition');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

LocalSyncService _service(_Library library) => LocalSyncService(
  store: library.store,
  bindAddress: InternetAddress.loopbackIPv4,
  advertisedAddress: InternetAddress.loopbackIPv4,
  allowLoopback: true,
  requestTimeout: const Duration(seconds: 5),
);

class _NoExternalNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Global proxy must not be used for LAN');
}

void main() {
  late Directory root;
  late _Library a;
  late _Library b;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    root = await Directory.systemTemp.createTemp('lira-sync-test-');
    a = _Library(await Directory('${root.path}/a').create());
    b = _Library(await Directory('${root.path}/b').create());
  });
  tearDown(() async {
    await a.database.close();
    await b.database.close();
    await root.delete(recursive: true);
  });

  test(
    'same file under different IDs merges notes and newer lower progress without duplicate books',
    () async {
      final bytes = _epub('Same content');
      await a.import('a', bytes);
      await b.import('b', bytes);
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'quote-a',
          bookId: 'a',
          text: 'First',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await b.highlights.saveHighlight(
        HighlightDto(
          id: 'quote-b',
          bookId: 'b',
          text: 'Second',
          note: 'Other device',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await a.progress.saveProgress(
        ReadingProgressDto(
          bookId: 'a',
          percentage: 80,
          location: 'old-position',
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await b.progress.saveProgress(
        ReadingProgressDto(
          bookId: 'b',
          percentage: 12,
          location: _locator,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      await a.receive(b);
      await b.receive(a);
      expect((await a.books.getAllBooks()).map((book) => book.id), ['a']);
      expect((await b.books.getAllBooks()).map((book) => book.id), ['b']);
      expect(
        (await a.highlights.getHighlightsForBook('a')).map((h) => h.id).toSet(),
        {'quote-a', 'quote-b'},
      );
      expect(
        (await b.highlights.getHighlightsForBook('b')).map((h) => h.id).toSet(),
        {'quote-a', 'quote-b'},
      );
      expect((await a.progress.getProgress('a'))!.percentage, 12);
      expect((await a.progress.getProgress('a'))!.location, _locator);
      expect((await b.receive(a)).totalChanges, 0);
      expect((await a.receive(b)).totalChanges, 0);
    },
  );

  test(
    'edits and deletion tombstones converge after repeated exchange',
    () async {
      await a.import('a', _epub('First'));
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'deleted',
          bookId: 'a',
          text: 'Remove me',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'edited',
          bookId: 'a',
          text: 'Keep quote',
          note: 'Old note',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await a.bookmarks.saveBookmark(
        BookmarkDto(
          id: 'mark-a',
          bookId: 'a',
          location: _locator,
          percentage: 15,
          createdAt: DateTime.utc(2026),
        ),
      );
      await b.receive(a);
      final bookB = (await b.books.getAllBooks()).single;
      await b.highlights.updateHighlightNote('edited', 'New note from B');
      await a.highlights.deleteHighlight('deleted');
      await a.bookmarks.deleteBookmark('mark-a');
      await a.receive(b);
      await b.receive(a);
      expect(
        (await a.highlights.getHighlightsForBook('a')).single.note,
        'New note from B',
      );
      expect(
        (await b.highlights.getHighlightsForBook(bookB.id)).single.id,
        'edited',
      );
      expect(await b.bookmarks.getBookmarksForBook(bookB.id), isEmpty);
      expect((await a.receive(b)).totalChanges, 0);
      expect((await b.receive(a)).totalChanges, 0);
    },
  );

  test(
    'independent bookmarks at one locator do not duplicate or resurrect known aliases',
    () async {
      final bytes = _epub('Bookmarked');
      await a.import('a', bytes);
      await b.import('b', bytes);
      for (final pair in [(a, 'a', 'mark-a'), (b, 'b', 'mark-b')]) {
        await pair.$1.bookmarks.saveBookmark(
          BookmarkDto(
            id: pair.$3,
            bookId: pair.$2,
            location: _locator,
            percentage: 25,
            createdAt: DateTime.utc(2026),
          ),
        );
      }
      await a.receive(b);
      await b.receive(a);
      final selected = (await a.bookmarks.getBookmarksForBook('a')).single;
      expect(
        (await b.bookmarks.getBookmarksForBook('b')).single.location,
        _locator,
      );
      await a.bookmarks.deleteBookmark(selected.id);
      await b.receive(a);
      await a.receive(b);
      expect(await a.bookmarks.getBookmarksForBook('a'), isEmpty);
      expect(await b.bookmarks.getBookmarksForBook('b'), isEmpty);
      expect((await b.receive(a)).totalChanges, 0);
    },
  );

  test(
    'deletion history survives database reopen and blocks an older peer copy',
    () async {
      await a.import('a', _epub('Persistent history'));
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'deleted-after-sync',
          bookId: 'a',
          text: 'Old peer quote',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await b.receive(a);
      final directory = await Directory('${root.path}/persistent').create();
      final initial = _Library(directory, persistent: true);
      try {
        await initial.receive(a);
        await initial.highlights.deleteHighlight('deleted-after-sync');
      } finally {
        await initial.database.close();
      }
      final reopened = _Library(directory, persistent: true);
      try {
        await b.receive(reopened);
        await b.receive(a);
        final bookB = (await b.books.getAllBooks()).single;
        expect(await b.highlights.getHighlightsForBook(bookB.id), isEmpty);
        await a.receive(b);
        expect(await a.highlights.getHighlightsForBook('a'), isEmpty);
        expect((await b.receive(reopened)).totalChanges, 0);
      } finally {
        await reopened.database.close();
      }
    },
  );

  test(
    'hash mismatch rejects file before publishing any library or annotation changes',
    () async {
      await a.import('a', _epub('Real file'));
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'quote',
          bookId: 'a',
          text: 'Quote',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      final wrong = await File(
        '${b.directory.path}/wrong.epub',
      ).writeAsBytes(_epub('Wrong file'));
      await expectLater(
        b.store.merge(await a.store.snapshot(), fetchBook: (_) async => wrong),
        throwsFormatException,
      );
      expect(await b.books.getAllBooks(), isEmpty);
      expect(await b.database.select(b.database.highlights).get(), isEmpty);
      expect(await wrong.exists(), isFalse);
    },
  );

  test(
    'a missing local file is repaired without duplicating the book or losing annotations',
    () async {
      final bytes = _epub('Repairable');
      await a.import('a', bytes);
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'kept',
          bookId: 'a',
          text: 'Keep this quote',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await b.receive(a);
      final before = (await b.books.getAllBooks()).single;
      await File(before.fileUrl!).delete();
      final result = await b.receive(a);
      final after = (await b.books.getAllBooks()).single;
      expect(after.id, before.id);
      expect(await File(after.fileUrl!).readAsBytes(), bytes);
      expect(
        (await b.highlights.getHighlightsForBook(after.id)).single.id,
        'kept',
      );
      expect(result.booksReceived, 1);
    },
  );

  test(
    'unsaved previews are not shared and a locally deleted book is not reimported',
    () async {
      await a.import('preview', _epub('Preview'), saved: false);
      expect((await a.store.snapshot()).records, isEmpty);
      await a.import('saved', _epub('Saved'));
      await b.receive(a);
      final bookB = (await b.books.getAllBooks()).single;
      await b.books.deleteBook(bookB.id);
      await b.receive(a);
      expect(await b.books.getAllBooks(), isEmpty);
      expect((await a.books.getAllBooks()).single.id, 'saved');
    },
  );

  test(
    'cached reading state reloads merged edits without reopening the app',
    () async {
      final bytes = _epub('Cached book');
      await a.import('a', bytes);
      await b.import('b', bytes);
      getIt.registerSingleton<HighlightsLocalRepository>(b.highlights);
      getIt.registerSingleton<BookmarksLocalRepository>(b.bookmarks);
      getIt.registerSingleton<ReadingProgressLocalRepository>(b.progress);
      addTearDown(getIt.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final highlights = highlightsControllerProvider('b');
      final bookmarks = bookmarksControllerProvider('b');
      final progress = readingProgressControllerProvider('b');
      container.listen(highlights, (_, _) {});
      container.listen(bookmarks, (_, _) {});
      container.listen(progress, (_, _) {});
      await container.read(highlights.future);
      await container.read(bookmarks.future);
      await container.read(progress.future);
      await a.highlights.saveHighlight(
        HighlightDto(
          id: 'new-quote',
          bookId: 'a',
          text: 'From peer',
          note: 'Merged note',
          location: _locator,
          createdAt: DateTime.utc(2026),
        ),
      );
      await a.bookmarks.saveBookmark(
        BookmarkDto(
          id: 'new-mark',
          bookId: 'a',
          location: _locator,
          percentage: 77,
          createdAt: DateTime.utc(2026),
        ),
      );
      await a.progress.saveProgress(
        ReadingProgressDto(
          bookId: 'a',
          percentage: 77,
          location: _locator,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await b.receive(a);
      container.invalidate(highlightsControllerProvider);
      container.invalidate(bookmarksControllerProvider);
      container.invalidate(readingProgressControllerProvider);
      expect(
        (await container.read(highlights.future)).single.note,
        'Merged note',
      );
      expect(
        (await container.read(bookmarks.future)).single.location,
        _locator,
      );
      expect((await container.read(progress.future))!.percentage, 77);
    },
  );

  test(
    'real encrypted loopback exchange requires approval, moves files both ways, and bypasses global proxies',
    () async {
      final bytesA = _epub('From A', large: true);
      final bytesB = _epub('From B');
      await a.import('a', bytesA);
      await b.import('b', bytesB);
      final host = _service(a);
      final peer = _service(b);
      addTearDown(host.close);
      addTearDown(peer.close);
      await HttpOverrides.runWithHttpOverrides(() async {
        await host.host();
        expect(host.phase, LocalSyncPhase.hosting);
        final join = peer.connect(host.invitation!);
        await _waitFor(() => host.phase == LocalSyncPhase.awaitingApproval);
        expect((await a.books.getAllBooks()).length, 1);
        expect((await b.books.getAllBooks()).length, 1);
        await host.approve();
        await join;
      }, _NoExternalNetwork());
      expect(host.phase, LocalSyncPhase.complete, reason: host.error);
      expect(peer.phase, LocalSyncPhase.complete, reason: peer.error);
      final localA = await a.books.getAllBooks();
      final localB = await b.books.getAllBooks();
      expect(localA.length, 2);
      expect(localB.length, 2);
      expect(
        await File(
          localA.singleWhere((book) => book.id != 'a').fileUrl!,
        ).readAsBytes(),
        bytesB,
      );
      expect(
        await File(
          localB.singleWhere((book) => book.id != 'b').fileUrl!,
        ).readAsBytes(),
        bytesA,
      );
    },
  );

  test(
    'wrong key cannot trigger approval or mutate the host, then rejection transfers no data',
    () async {
      await a.import('a', _epub('Private'));
      final host = _service(a);
      final peer = _service(b);
      addTearDown(host.close);
      addTearDown(peer.close);
      await host.host();
      final invitation = host.invitation!;
      final payload =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    base64Url.normalize(invitation.substring(10)),
                  ),
                ),
              )
              as Map<String, dynamic>;
      payload['k'] = base64Url.encode(List<int>.filled(32, 0));
      final bad =
          'lira-sync:${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}';
      await peer.connect(bad);
      expect(peer.phase, LocalSyncPhase.failed);
      expect(host.phase, LocalSyncPhase.hosting);
      expect(await b.books.getAllBooks(), isEmpty);
      final join = peer.connect(invitation);
      await _waitFor(() => host.phase == LocalSyncPhase.awaitingApproval);
      await host.reject();
      await join;
      expect(peer.phase, LocalSyncPhase.failed);
      expect(peer.error, 'rejected');
      expect(await b.books.getAllBooks(), isEmpty);
    },
  );

  test(
    'stopping a pending pairing ends both sockets without import and invalidates its QR',
    () async {
      await a.import('a', _epub('Private'));
      final host = _service(a);
      final peer = _service(b);
      addTearDown(host.close);
      addTearDown(peer.close);
      await host.host();
      final stale = host.invitation!;
      final join = peer.connect(stale);
      await _waitFor(() => host.phase == LocalSyncPhase.awaitingApproval);
      await host.stop();
      await join;
      expect(host.phase, LocalSyncPhase.idle);
      expect(peer.phase, LocalSyncPhase.failed);
      expect(await b.books.getAllBooks(), isEmpty);
      await host.host();
      expect(host.invitation, isNot(stale));
      await peer.connect(stale);
      expect(peer.phase, LocalSyncPhase.failed);
      expect(host.phase, LocalSyncPhase.hosting);
    },
  );
}
