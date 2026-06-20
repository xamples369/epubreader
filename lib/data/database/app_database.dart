import 'package:drift/drift.dart';

import 'tables/books_table.dart';
import 'tables/reading_positions_table.dart';
import 'tables/settings_kv_table.dart';
import 'tables/watched_folders_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Books, ReadingPositions, SettingsKv, WatchedFolders],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
