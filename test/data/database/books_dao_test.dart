import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/database/app_database.dart';
import 'package:epubreader/data/database/daos/books_dao.dart';

void main() {
  late AppDatabase db;
  late BooksDao dao;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    dao = BooksDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert + getAll round trip', () async {
    final row = BooksCompanion.insert(
      id: 'b1',
      title: 'Alice',
      filePath: '/tmp/alice.epub',
      storageMode: 'managed',
      addedAt: DateTime(2026, 6, 20),
      author: const Value('Lewis Carroll'),
    );
    await dao.insertBook(row);

    final all = await dao.getAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'b1');
    expect(all.single.title, 'Alice');
    expect(all.single.author, 'Lewis Carroll');
  });

  test('getById returns null for missing id', () async {
    final result = await dao.getById('nope');
    expect(result, isNull);
  });

  test('deleteById removes the book', () async {
    await dao.insertBook(BooksCompanion.insert(
      id: 'b1',
      title: 'A',
      filePath: '/x',
      storageMode: 'managed',
      addedAt: DateTime(2026, 6, 20),
    ));
    await dao.deleteById('b1');
    expect(await dao.getAll(), isEmpty);
  });
}
