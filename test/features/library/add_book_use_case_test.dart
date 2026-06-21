import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/database/app_database.dart';
import 'package:epubreader/data/database/daos/books_dao.dart';
import 'package:epubreader/data/epub/epub_metadata_parser.dart';
import 'package:epubreader/data/storage/cover_storage.dart';
import 'package:epubreader/features/library/add_book_use_case.dart';

void main() {
  late Directory tmp;
  late AppDatabase db;
  late BooksDao booksDao;
  late CoverStorage cover;
  late AddBookUseCase useCase;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('addbook_uc_');
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    booksDao = BooksDao(db);
    cover = CoverStorage(baseDir: Directory('${tmp.path}/covers'));
    useCase = AddBookUseCase(
      booksDao: booksDao,
      coverStorage: cover,
      managedLibraryDir: Directory('${tmp.path}/books'),
      parse: _fakeParse,
    );
  });

  tearDown(() async {
    await db.close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Windows may briefly lock files; ignore.
    }
  });

  test('addBook stores file copy, cover, and DB row', () async {
    final src = File('${tmp.path}/orig.epub')..writeAsBytesSync([1, 2, 3, 4]);

    final book = await useCase.addBook(src);

    expect(book.title, 'Fake Title');
    expect(book.author, 'Fake Author');
    expect(book.storageMode, 'managed');
    expect(File(book.filePath).existsSync(), isTrue);
    expect(book.filePath.contains('books'), isTrue);
    expect(File(book.coverPath!).existsSync(), isTrue);

    final rows = await booksDao.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.id, book.id);
  });
}

Future<EpubMetadata> _fakeParse(File f) async {
  return EpubMetadata(
    title: 'Fake Title',
    author: 'Fake Author',
    language: 'en',
    coverBytes: Uint8List.fromList(List<int>.generate(150, (i) => i)),
  );
}
