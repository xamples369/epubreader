import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/database/app_database.dart';
import 'package:epubreader/data/database/daos/settings_kv_dao.dart';

void main() {
  late AppDatabase db;
  late SettingsKvDao dao;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    dao = SettingsKvDao(db);
  });

  tearDown(() async => db.close());

  test('get on missing key returns null', () async {
    expect(await dao.getString('missing'), isNull);
  });

  test('set then get roundtrips a string', () async {
    await dao.setString('storageMode', 'managed');
    expect(await dao.getString('storageMode'), 'managed');
  });

  test('set overwrites existing value', () async {
    await dao.setString('startupScreen', 'home');
    await dao.setString('startupScreen', 'lastBook');
    expect(await dao.getString('startupScreen'), 'lastBook');
  });
}
