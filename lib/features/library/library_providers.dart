import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import '../../data/database/connection.dart';
import '../../data/database/daos/books_dao.dart';
import '../../data/database/daos/settings_kv_dao.dart';
import '../../data/storage/cover_storage.dart';
import '../../domain/models/book.dart';
import 'add_book_use_case.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final booksDaoProvider = Provider<BooksDao>(
  (ref) => BooksDao(ref.watch(appDatabaseProvider)),
);

final settingsKvDaoProvider = Provider<SettingsKvDao>(
  (ref) => SettingsKvDao(ref.watch(appDatabaseProvider)),
);

final coverStorageProvider = FutureProvider<CoverStorage>(
  (ref) async => CoverStorage.system(),
);

final managedLibraryDirProvider = FutureProvider<Directory>((ref) async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}/EpubReader/Books');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir;
});

final addBookUseCaseProvider = FutureProvider<AddBookUseCase>((ref) async {
  final coverStorage = await ref.watch(coverStorageProvider.future);
  final managedDir = await ref.watch(managedLibraryDirProvider.future);
  return AddBookUseCase(
    booksDao: ref.watch(booksDaoProvider),
    coverStorage: coverStorage,
    managedLibraryDir: managedDir,
  );
});

final libraryBooksProvider = StreamProvider<List<BookModel>>((ref) {
  final dao = ref.watch(booksDaoProvider);
  return dao.watchAll().map(
        (rows) => rows.map(BookModel.fromRow).toList(growable: false),
      );
});
