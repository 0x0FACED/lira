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
