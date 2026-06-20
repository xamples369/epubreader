import 'package:drift/drift.dart';

class SettingsKv extends Table {
  TextColumn get key => text()();
  TextColumn get jsonValue => text()();

  @override
  Set<Column> get primaryKey => {key};
}
