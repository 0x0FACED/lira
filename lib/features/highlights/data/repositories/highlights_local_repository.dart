import 'package:injectable/injectable.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/highlight_dto.dart';

@injectable
class HighlightsLocalRepository {
  final AppDatabase _db;

  HighlightsLocalRepository(this._db);

  Future<void> saveHighlight(HighlightDto highlight) async {
    await _db
        .into(_db.highlights)
        .insert(
          HighlightsCompanion.insert(
            id: highlight.id,
            bookId: highlight.bookId,
            textContent: highlight.text,
            color: Value(highlight.color),
            location: highlight.location,
            note: Value(highlight.note),
            createdAt: highlight.createdAt,
          ),
          mode: InsertMode.replace,
        );
  }

  Future<List<HighlightDto>> getHighlightsForBook(String bookId) async {
    final query = _db.select(_db.highlights)
      ..where((t) => t.bookId.equals(bookId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final entries = await query.get();
    return entries
        .map(
          (e) => HighlightDto(
            id: e.id,
            bookId: e.bookId,
            text: e.textContent,
            color: e.color,
            location: e.location,
            note: e.note,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }

  Future<void> updateHighlightNote(String id, String? note) async {
    await (_db.update(_db.highlights)..where((t) => t.id.equals(id))).write(
      HighlightsCompanion(note: Value(note)),
    );
  }

  Future<void> deleteHighlight(String id) async {
    await (_db.delete(_db.highlights)..where((t) => t.id.equals(id))).go();
  }
}
