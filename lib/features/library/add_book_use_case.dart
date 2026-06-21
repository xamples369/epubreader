import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../../data/database/daos/books_dao.dart';
import '../../data/database/app_database.dart';
import '../../data/epub/epub_metadata_parser.dart';
import '../../data/storage/cover_storage.dart';
import '../../domain/models/book.dart';

typedef ParseFn = Future<EpubMetadata> Function(File file);

class AddBookUseCase {
  final BooksDao booksDao;
  final CoverStorage coverStorage;
  final Directory managedLibraryDir;
  final ParseFn parse;

  AddBookUseCase({
    required this.booksDao,
    required this.coverStorage,
    required this.managedLibraryDir,
    ParseFn? parse,
  }) : parse = parse ?? EpubMetadataParser.parse;

  Future<BookModel> addBook(File sourceFile) async {
    final meta = await parse(sourceFile);

    final bookId = _generateBookId(meta);
    if (!managedLibraryDir.existsSync()) {
      managedLibraryDir.createSync(recursive: true);
    }
    final managedPath = '${managedLibraryDir.path}/$bookId.epub';
    await sourceFile.copy(managedPath);

    String? coverPath;
    if (meta.coverBytes != null) {
      coverPath = await coverStorage.store(bookId, meta.coverBytes!);
    }

    final size = await File(managedPath).length();
    final addedAt = DateTime.now();

    final companion = BooksCompanion.insert(
      id: bookId,
      title: meta.title,
      filePath: managedPath,
      storageMode: 'managed',
      addedAt: addedAt,
      author: Value(meta.author),
      language: Value(meta.language),
      coverPath: Value(coverPath),
      fileSizeBytes: Value(size),
    );
    await booksDao.insertBook(companion);

    final row = await booksDao.getById(bookId);
    return BookModel.fromRow(row!);
  }

  String _generateBookId(EpubMetadata meta) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final slug = meta.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final short = slug.length > 40 ? slug.substring(0, 40) : slug;
    return '$short-$ts';
  }
}
