import 'package:drift/drift.dart';

@DataClassName('BookEntity')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author =>
      text().withDefault(const Constant('Unknown Author'))();
  TextColumn get format => text()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get fileUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get contentHash => text().nullable()();
  BoolColumn get isSaved => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ReadingProgressEntity')
class ReadingProgresses extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  RealColumn get percentage => real()();
  TextColumn get location => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}

@DataClassName('HighlightEntity')
class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get textContent => text()();
  TextColumn get color => text().withDefault(const Constant('#BB86FC'))();
  TextColumn get location => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BookmarkEntity')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id)();
  TextColumn get location => text()();
  RealColumn get percentage => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {bookId, location},
  ];
}

/// Local revisions also cover records whose book has not been fingerprinted yet.
@DataClassName('SyncRevisionEntity')
class SyncRevisions extends Table {
  TextColumn get kind => text()();
  TextColumn get entityId => text()();
  TextColumn get bookId => text()();
  IntColumn get modifiedAt => integer()();
  TextColumn get deviceId => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {kind, entityId};
}

@DataClassName('SyncIdentityEntity')
class SyncIdentities extends Table {
  IntColumn get id => integer()();
  TextColumn get deviceId => text()();
  IntColumn get clock => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A library removal is local, not a request to delete another device's book.
@DataClassName('SyncExcludedBookEntity')
class SyncExcludedBooks extends Table {
  TextColumn get bookHash => text()();

  @override
  Set<Column> get primaryKey => {bookHash};
}
