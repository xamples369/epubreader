import 'package:meta/meta.dart';

import '../../data/database/app_database.dart';

@immutable
class BookModel {
  final String id;
  final String title;
  final String? author;
  final String? language;
  final String filePath;
  final String storageMode;
  final String? coverPath;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int? fileSizeBytes;

  const BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.filePath,
    required this.storageMode,
    required this.coverPath,
    required this.addedAt,
    required this.lastReadAt,
    required this.fileSizeBytes,
  });

  bool get isUnread => lastReadAt == null;

  factory BookModel.fromRow(Book row) => BookModel(
        id: row.id,
        title: row.title,
        author: row.author,
        language: row.language,
        filePath: row.filePath,
        storageMode: row.storageMode,
        coverPath: row.coverPath,
        addedAt: row.addedAt,
        lastReadAt: row.lastReadAt,
        fileSizeBytes: row.fileSizeBytes,
      );
}
