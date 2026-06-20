import 'package:drift/drift.dart';

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get filePath => text()();
  TextColumn get storageMode => text()(); // 'managed' | 'watched'
  TextColumn get coverPath => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
