import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_change_tracker.dart';
import '../../domain/models/reading_progress_dto.dart';

@injectable
class ReadingProgressLocalRepository {
  final AppDatabase _db;

  ReadingProgressLocalRepository(this._db);

  /// Watches saved books' progress, including changes applied by local sync.
  Stream<Map<String, ReadingProgressDto>> watchLibraryProgress() {
    final query = _db.select(_db.readingProgresses).join([
      innerJoin(
        _db.books,
        _db.books.id.equalsExp(_db.readingProgresses.bookId),
        useColumns: false,
      ),
    ])..where(_db.books.isSaved.equals(true));

    return query.watch().map((rows) {
      final progressByBook = <String, ReadingProgressDto>{};
      for (final row in rows) {
        final progress = row.readTable(_db.readingProgresses);
        progressByBook[progress.bookId] = ReadingProgressDto(
          bookId: progress.bookId,
          percentage: progress.percentage,
          location: progress.location,
          updatedAt: progress.updatedAt,
        );
      }
      return progressByBook;
    });
  }

  Future<void> saveProgress(ReadingProgressDto progress) async {
    final companion = ReadingProgressesCompanion.insert(
      bookId: progress.bookId,
      percentage: progress.percentage,
      location: progress.location,
      updatedAt: progress.updatedAt,
    );

    await _db.transaction(() async {
      await _db.into(_db.readingProgresses).insertOnConflictUpdate(companion);
      await SyncChangeTracker(_db).captureProgress(progress.bookId);
    });
  }

  Future<ReadingProgressDto?> getProgress(String bookId) async {
    final query = _db.select(_db.readingProgresses)
      ..where((t) => t.bookId.equals(bookId));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    return ReadingProgressDto(
      bookId: result.bookId,
      percentage: result.percentage,
      location: result.location,
      updatedAt: result.updatedAt,
    );
  }
}
