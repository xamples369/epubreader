import 'package:drift/drift.dart';

import '../app_database.dart';

class BooksDao extends DatabaseAccessor<AppDatabase> {
  BooksDao(super.db);

  $BooksTable get _books => attachedDatabase.books;

  Future<void> insertBook(BooksCompanion row) async {
    await into(_books).insert(row);
  }

  Future<List<Book>> getAll() async {
    return (select(_books)..orderBy([(b) => OrderingTerm.desc(b.addedAt)])).get();
  }

  Future<Book?> getById(String id) async {
    return (select(_books)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<void> deleteById(String id) async {
    await (delete(_books)..where((b) => b.id.equals(id))).go();
  }

  Stream<List<Book>> watchAll() {
    return (select(_books)..orderBy([(b) => OrderingTerm.desc(b.addedAt)])).watch();
  }
}
