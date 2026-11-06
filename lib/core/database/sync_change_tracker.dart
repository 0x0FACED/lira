import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Call capture methods in the same transaction as the corresponding mutation.
/// File fingerprinting deliberately happens before entering that transaction.
class SyncChangeTracker {
  SyncChangeTracker(this.database);
  final AppDatabase database;

  static Future<String?> fingerprint(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return (await sha256.bind(file.openRead()).first).toString();
  }

  Future<String?> prepareBook(String bookId) async {
    final book = await (database.select(
      database.books,
    )..where((row) => row.id.equals(bookId))).getSingleOrNull();
    if (book == null) return null;
    final hash = book.contentHash;
    return hash != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)
        ? hash
        : await fingerprint(book.fileUrl);
  }

  Future<void> setBookHash(String bookId, String? hash) async {
    if (hash == null) return;
    await (database.update(database.books)
          ..where((row) => row.id.equals(bookId)))
        .write(BooksCompanion(contentHash: Value(hash)));
  }

  Future<SyncIdentityEntity> identity() async {
    var row = await (database.select(
      database.syncIdentities,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (row != null) return row;
    await database
        .into(database.syncIdentities)
        .insert(
          SyncIdentitiesCompanion.insert(
            id: const Value(1),
            deviceId: const Uuid().v4(),
            clock: 0,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    row = await (database.select(
      database.syncIdentities,
    )..where((row) => row.id.equals(1))).getSingle();
    return row;
  }

  Future<void> observeClock(int remoteClock) async {
    final current = await identity();
    if (remoteClock <= current.clock) return;
    await (database.update(database.syncIdentities)
          ..where((row) => row.id.equals(1)))
        .write(SyncIdentitiesCompanion(clock: Value(remoteClock)));
  }

  Future<void> captureBook(String id, {bool seed = false}) async {
    final row = await (database.select(
      database.books,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _capture(
      'book',
      id,
      id,
      {
        'title': row.title,
        'author': row.author,
        'format': row.format.toLowerCase(),
        'createdAt': row.createdAt.microsecondsSinceEpoch,
        'pageCount': row.pageCount,
        'fileSizeBytes': row.fileSizeBytes,
      },
      seed: seed,
      timestamp: row.createdAt,
    );
  }

  Future<void> captureProgress(String bookId, {bool seed = false}) async {
    final row = await (database.select(
      database.readingProgresses,
    )..where((row) => row.bookId.equals(bookId))).getSingleOrNull();
    if (row == null) return;
    await _capture(
      'progress',
      bookId,
      bookId,
      {
        'percentage': row.percentage,
        'location': row.location,
        'updatedAt': row.updatedAt.microsecondsSinceEpoch,
      },
      seed: seed,
      timestamp: row.updatedAt,
    );
  }

  Future<void> captureHighlight(
    String id, {
    bool deleted = false,
    bool seed = false,
  }) async {
    final row = await (database.select(
      database.highlights,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _capture(
      'highlight',
      id,
      row.bookId,
      {
        'text': row.textContent,
        'color': row.color,
        'location': row.location,
        'note': row.note,
        'createdAt': row.createdAt.microsecondsSinceEpoch,
      },
      deleted: deleted,
      seed: seed,
      timestamp: row.createdAt,
    );
  }

  Future<void> captureBookmark(
    String id, {
    bool deleted = false,
    bool seed = false,
  }) async {
    final row = await (database.select(
      database.bookmarks,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (deleted) {
      // Independently-created bookmarks may name the same exact position with
      // different UUIDs. Removing that position must tombstone all known aliases.
      final book = await (database.select(
        database.books,
      )..where((book) => book.id.equals(row.bookId))).getSingleOrNull();
      final books = book?.contentHash == null
          ? <BookEntity>[]
          : await (database.select(database.books)..where(
                  (other) => other.contentHash.equals(book!.contentHash!),
                ))
                .get();
      final bookIds = {row.bookId, ...books.map((book) => book.id)};
      final aliases =
          await (database.select(database.syncRevisions)..where(
                (revision) =>
                    revision.kind.equals('bookmark') &
                    revision.bookId.isIn(bookIds) &
                    revision.deleted.equals(false),
              ))
              .get();
      for (final alias in aliases) {
        final payload = jsonDecode(alias.payload) as Map<String, dynamic>;
        if (payload['location'] == row.location && alias.entityId != id) {
          await _capture(
            'bookmark',
            alias.entityId,
            alias.bookId,
            payload,
            deleted: true,
          );
        }
      }
    }
    await _capture(
      'bookmark',
      id,
      row.bookId,
      {
        'location': row.location,
        'percentage': row.percentage,
        'createdAt': row.createdAt.microsecondsSinceEpoch,
      },
      deleted: deleted,
      seed: seed,
      timestamp: row.createdAt,
    );
  }

  Future<void> seedBook(String id) async {
    await captureBook(id, seed: true);
    await captureProgress(id, seed: true);
    final highlights = await (database.select(
      database.highlights,
    )..where((row) => row.bookId.equals(id))).get();
    for (final row in highlights) {
      await captureHighlight(row.id, seed: true);
    }
    final bookmarks = await (database.select(
      database.bookmarks,
    )..where((row) => row.bookId.equals(id))).get();
    for (final row in bookmarks) {
      await captureBookmark(row.id, seed: true);
    }
  }

  Future<void> _capture(
    String kind,
    String id,
    String bookId,
    Map<String, dynamic> payload, {
    bool deleted = false,
    bool seed = false,
    DateTime? timestamp,
  }) async {
    final existing =
        await (database.select(database.syncRevisions)
              ..where((row) => row.kind.equals(kind) & row.entityId.equals(id)))
            .getSingleOrNull();
    if (seed && existing != null) return;
    final encoded = jsonEncode(deleted ? <String, dynamic>{} : payload);
    if (existing != null &&
        existing.deleted == deleted &&
        existing.bookId == bookId &&
        existing.payload == encoded)
      return;
    final current = await identity();
    final clock = seed
        ? math.max(0, timestamp!.microsecondsSinceEpoch)
        : math.max(DateTime.now().microsecondsSinceEpoch, current.clock + 1);
    await observeClock(clock);
    await database
        .into(database.syncRevisions)
        .insertOnConflictUpdate(
          SyncRevisionsCompanion.insert(
            kind: kind,
            entityId: id,
            bookId: bookId,
            modifiedAt: clock,
            deviceId: current.deviceId,
            deleted: Value(deleted),
            payload: encoded,
          ),
        );
  }
}
