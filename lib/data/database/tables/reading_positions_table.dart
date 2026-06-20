import 'package:drift/drift.dart';

import 'books_table.dart';

class ReadingPositions extends Table {
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  RealColumn get progressInChapter => real()(); // 0.0 – 1.0
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {bookId};
}
