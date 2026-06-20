import 'package:drift/drift.dart';

class WatchedFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
}
