import 'package:injectable/injectable.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/reading_progress_dto.dart';

@injectable
class ReadingProgressLocalRepository {
  final AppDatabase _db;

  ReadingProgressLocalRepository(this._db);

  Future<void> saveProgress(ReadingProgressDto progress) async {
    final companion = ReadingProgressesCompanion.insert(
      bookId: progress.bookId,
      percentage: progress.percentage,
      location: progress.location,
      updatedAt: progress.updatedAt,
    );

    await _db.into(_db.readingProgresses).insertOnConflictUpdate(companion);
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
