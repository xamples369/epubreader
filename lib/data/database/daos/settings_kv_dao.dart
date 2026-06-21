import 'package:drift/drift.dart';

import '../app_database.dart';

class SettingsKvDao extends DatabaseAccessor<AppDatabase> {
  SettingsKvDao(super.db);

  $SettingsKvTable get _settings => attachedDatabase.settingsKv;

  Future<String?> getString(String key) async {
    final row = await (select(_settings)..where((r) => r.key.equals(key)))
        .getSingleOrNull();
    return row?.jsonValue;
  }

  Future<void> setString(String key, String value) async {
    await into(_settings).insertOnConflictUpdate(
      SettingsKvCompanion.insert(key: key, jsonValue: value),
    );
  }
}
