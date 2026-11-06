import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/sync_change_tracker.dart';
import '../domain/sync_models.dart';

class LocalSyncStore {
  LocalSyncStore({required AppDatabase database, required Directory directory})
    : _database = database,
      _directory = directory,
      _tracker = SyncChangeTracker(database);

  final AppDatabase _database;
  final Directory _directory;
  final SyncChangeTracker _tracker;

  Future<SyncSnapshot> snapshot() async {
    await _prepare();
    return _database.transaction(
      () async => SyncSnapshot(
        records: (await _records()).values.toList()..sort(_recordOrder),
      ),
    );
  }

  Future<File?> bookFile(String hash) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid book fingerprint');
    }
    final books =
        await (_database.select(_database.books)..where(
              (row) => row.contentHash.equals(hash) & row.isSaved.equals(true),
            ))
            .get();
    for (final book in books) {
      if (await SyncChangeTracker.fingerprint(book.fileUrl) == hash) {
        return File(book.fileUrl!);
      }
    }
    return null;
  }

  Future<SyncMergeResult> merge(
    SyncSnapshot remote, {
    required Future<File> Function(String hash) fetchBook,
  }) async {
    // Validate even programmatically supplied snapshots, not only wire JSON.
    final validated = SyncSnapshot.fromJson(remote.toJson());
    final incoming = <String, SyncRecord>{};
    for (final record in validated.records) {
      final key = _key(record);
      final previous = incoming[key];
      if (previous != null && previous.bookHash != record.bookHash) {
        throw const FormatException(
          'Annotation identity belongs to another book',
        );
      }
      if (previous == null || record.compareRevision(previous) > 0) {
        incoming[key] = record;
      }
    }
    await _prepare();
    final known = await _booksByHash();
    final excluded = await _excluded();
    final staged = <String, _StagedBook>{};
    final retained = <String>{};
    var committed = false;
    try {
      // All network/file IO precedes the transaction. Never hold SQLite locks
      // while waiting for the peer, and never publish an unverified file.
      for (final record in incoming.values.where((row) => row.kind == 'book')) {
        if (excluded.contains(record.bookHash)) continue;
        var available = false;
        for (final copy in known[record.bookHash] ?? const <BookEntity>[]) {
          if (copy.fileUrl != null && await File(copy.fileUrl!).exists()) {
            available = true;
            break;
          }
        }
        if (available) continue;
        final temporary = await fetchBook(record.bookHash);
        File? managed;
        try {
          if (await SyncChangeTracker.fingerprint(temporary.path) !=
              record.bookHash) {
            throw const FormatException(
              'Transferred book fingerprint does not match',
            );
          }
          final id = const Uuid().v4();
          final booksDirectory = Directory(p.join(_directory.path, 'books'));
          await booksDirectory.create(recursive: true);
          managed = File(
            p.join(booksDirectory.path, '$id.${record.payload['format']}'),
          );
          await temporary.copy(managed.path);
          final length = await managed.length();
          staged[record.bookHash] = _StagedBook(
            id: id,
            file: managed,
            length: length,
          );
        } catch (_) {
          if (managed != null) await _remove(managed);
          rethrow;
        } finally {
          await _remove(temporary);
        }
      }
      var booksReceived = 0;
      var highlightsChanged = 0;
      var bookmarksChanged = 0;
      var progressChanged = 0;
      await _database.transaction(() async {
        final blocked = await _excluded();
        final books = await _booksByHash();
        for (final entry in staged.entries) {
          if (blocked.contains(entry.key)) continue;
          final record = incoming['book:${entry.key}']!;
          final file = entry.value;
          final copies = books[entry.key];
          if (copies == null) {
            await _database
                .into(_database.books)
                .insert(
                  BooksCompanion.insert(
                    id: file.id,
                    title: record.payload['title'] as String,
                    author: Value(record.payload['author'] as String),
                    format: record.payload['format'] as String,
                    fileUrl: Value(file.file.path),
                    createdAt: _date(record.payload['createdAt']),
                    pageCount: Value(record.payload['pageCount'] as int),
                    fileSizeBytes: Value(file.length),
                    contentHash: Value(entry.key),
                  ),
                );
          } else {
            await (_database.update(_database.books)
                  ..where((row) => row.id.isIn(copies.map((book) => book.id))))
                .write(
                  BooksCompanion(
                    fileUrl: Value(file.file.path),
                    fileSizeBytes: Value(file.length),
                  ),
                );
          }
          books[entry.key] =
              await (_database.select(_database.books)..where(
                    (row) =>
                        row.contentHash.equals(entry.key) &
                        row.isSaved.equals(true),
                  ))
                  .get();
          retained.add(file.file.path);
          booksReceived++;
        }
        final current = await _records();
        final ordered = incoming.values.toList()..sort(_recordOrder);
        final affectedBookmarks = <String>{};
        for (final record in ordered) {
          if (blocked.contains(record.bookHash)) continue;
          final copies = books[record.bookHash];
          // Orphan records cannot create a book or promote a discover preview.
          if (copies == null || copies.isEmpty) continue;
          final key = _key(record);
          final previous = current[key];
          if (previous != null && previous.bookHash != record.bookHash) {
            throw const FormatException(
              'Annotation identity belongs to another book',
            );
          }
          if (previous != null && record.compareRevision(previous) <= 0)
            continue;
          await _tracker.observeClock(record.modifiedAt);
          switch (record.kind) {
            case 'book':
              for (final book in copies) {
                await (_database.update(
                  _database.books,
                )..where((row) => row.id.equals(book.id))).write(
                  BooksCompanion(
                    title: Value(record.payload['title'] as String),
                    author: Value(record.payload['author'] as String),
                    pageCount: Value(record.payload['pageCount'] as int),
                  ),
                );
                await _saveRevision(record, book.id, book.id);
              }
            case 'progress':
              for (final book in copies) {
                if (record.deleted) {
                  await (_database.delete(
                    _database.readingProgresses,
                  )..where((row) => row.bookId.equals(book.id))).go();
                } else {
                  await _database
                      .into(_database.readingProgresses)
                      .insertOnConflictUpdate(
                        ReadingProgressesCompanion.insert(
                          bookId: book.id,
                          percentage: (record.payload['percentage'] as num)
                              .toDouble(),
                          location: record.payload['location'] as String,
                          updatedAt: _date(record.payload['updatedAt']),
                        ),
                      );
                }
                await _saveRevision(record, book.id, book.id);
              }
              progressChanged++;
            case 'highlight':
              if (record.deleted) {
                await (_database.delete(
                  _database.highlights,
                )..where((row) => row.id.equals(record.id))).go();
              } else {
                await _database
                    .into(_database.highlights)
                    .insertOnConflictUpdate(
                      HighlightsCompanion.insert(
                        id: record.id,
                        bookId: copies.first.id,
                        textContent: record.payload['text'] as String,
                        color: Value(record.payload['color'] as String),
                        location: record.payload['location'] as String,
                        note: Value(record.payload['note'] as String?),
                        createdAt: _date(record.payload['createdAt']),
                      ),
                    );
              }
              await _saveRevision(record, record.id, copies.first.id);
              highlightsChanged++;
            case 'bookmark':
              await _saveRevision(record, record.id, copies.first.id);
              affectedBookmarks.add(record.bookHash);
              bookmarksChanged++;
          }
          current[key] = record;
        }
        for (final hash in affectedBookmarks) {
          await _materializeBookmarks(hash, books[hash]!, current.values);
        }
      });
      committed = true;
      return SyncMergeResult(
        booksReceived: booksReceived,
        highlightsChanged: highlightsChanged,
        bookmarksChanged: bookmarksChanged,
        progressChanged: progressChanged,
      );
    } finally {
      for (final book in staged.values) {
        if (!committed || !retained.contains(book.file.path))
          await _remove(book.file);
      }
    }
  }

  Future<void> _prepare() async {
    final books = await (_database.select(
      _database.books,
    )..where((row) => row.isSaved.equals(true))).get();
    final hashes = <String, String>{};
    for (final book in books) {
      if (book.contentHash != null &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(book.contentHash!))
        continue;
      final hash = await SyncChangeTracker.fingerprint(book.fileUrl);
      if (hash != null) hashes[book.id] = hash;
    }
    await _database.transaction(() async {
      await _tracker.identity();
      for (final book in books) {
        final hash = hashes[book.id];
        if (hash != null) {
          await (_database.update(_database.books)..where(
                (row) =>
                    row.id.equals(book.id) &
                    (book.contentHash == null
                        ? row.contentHash.isNull()
                        : row.contentHash.equals(book.contentHash!)) &
                    row.fileUrl.equals(book.fileUrl!),
              ))
              .write(BooksCompanion(contentHash: Value(hash)));
        }
        // Seed pre-sync libraries with their original timestamps, not "now".
        // Later repository edits/deletes always receive a fresh logical clock.
        await _tracker.seedBook(book.id);
      }
    });
  }

  Future<Map<String, List<BookEntity>>> _booksByHash() async {
    final rows =
        await (_database.select(_database.books)
              ..where(
                (row) => row.isSaved.equals(true) & row.contentHash.isNotNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final result = <String, List<BookEntity>>{};
    for (final row in rows) {
      if (row.format.toLowerCase() != 'epub' &&
          row.format.toLowerCase() != 'pdf')
        continue;
      (result[row.contentHash!] ??= []).add(row);
    }
    return result;
  }

  Future<Set<String>> _excluded() async =>
      (await _database.select(_database.syncExcludedBooks).get())
          .map((row) => row.bookHash)
          .toSet();

  Future<Map<String, SyncRecord>> _records() async {
    final books = await _booksByHash();
    final blocked = await _excluded();
    final hashes = <String, String>{
      for (final entry in books.entries)
        if (!blocked.contains(entry.key))
          for (final book in entry.value) book.id: entry.key,
    };
    final revisions = await _database.select(_database.syncRevisions).get();
    final result = <String, SyncRecord>{};
    for (final revision in revisions) {
      final hash = hashes[revision.bookId];
      if (hash == null) continue;
      final record = SyncRecord(
        kind: revision.kind,
        id: revision.kind == 'book' || revision.kind == 'progress'
            ? hash
            : revision.entityId,
        bookHash: hash,
        modifiedAt: revision.modifiedAt,
        deviceId: revision.deviceId,
        deleted: revision.deleted,
        payload: jsonDecode(revision.payload) as Map<String, dynamic>,
      );
      final key = _key(record);
      final previous = result[key];
      if (previous == null || record.compareRevision(previous) > 0)
        result[key] = record;
    }
    return result;
  }

  Future<void> _saveRevision(
    SyncRecord record,
    String entityId,
    String bookId,
  ) => _database
      .into(_database.syncRevisions)
      .insertOnConflictUpdate(
        SyncRevisionsCompanion.insert(
          kind: record.kind,
          entityId: entityId,
          bookId: bookId,
          modifiedAt: record.modifiedAt,
          deviceId: record.deviceId,
          deleted: Value(record.deleted),
          payload: jsonEncode(record.payload),
        ),
      );

  Future<void> _materializeBookmarks(
    String hash,
    List<BookEntity> books,
    Iterable<SyncRecord> records,
  ) async {
    final positions = <String, SyncRecord>{};
    for (final record in records) {
      if (record.kind != 'bookmark' || record.bookHash != hash) continue;
      final location = record.payload['location'];
      if (location is! String) continue;
      final previous = positions[location];
      final comparison = previous == null
          ? 1
          : record.compareRevision(previous);
      if (previous == null ||
          comparison > 0 ||
          (comparison == 0 && record.id.compareTo(previous.id) > 0)) {
        positions[location] = record;
      }
    }
    // The database intentionally permits only one bookmark per exact locator.
    // The journal retains all UUIDs so independent libraries converge without
    // losing deletion/conflict history for aliases of the same position.
    await (_database.delete(
      _database.bookmarks,
    )..where((row) => row.bookId.isIn(books.map((book) => book.id)))).go();
    for (final record in positions.values.where((row) => !row.deleted)) {
      await _database
          .into(_database.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              id: record.id,
              bookId: books.first.id,
              location: record.payload['location'] as String,
              percentage: (record.payload['percentage'] as num).toDouble(),
              createdAt: _date(record.payload['createdAt']),
            ),
          );
    }
  }
}

class _StagedBook {
  const _StagedBook({
    required this.id,
    required this.file,
    required this.length,
  });
  final String id;
  final File file;
  final int length;
}

String _key(SyncRecord record) => '${record.kind}:${record.id}';

int _recordOrder(SyncRecord first, SyncRecord second) {
  const order = {'book': 0, 'progress': 1, 'highlight': 2, 'bookmark': 3};
  final comparison = order[first.kind]!.compareTo(order[second.kind]!);
  return comparison != 0 ? comparison : first.id.compareTo(second.id);
}

DateTime _date(dynamic value) =>
    DateTime.fromMicrosecondsSinceEpoch(value as int, isUtc: true);

Future<void> _remove(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best-effort cleanup must not replace the transfer/transaction failure.
  }
}
