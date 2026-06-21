import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/database/app_database.dart';
import 'package:epubreader/domain/models/book.dart';

void main() {
  test('BookModel.fromRow maps all fields', () {
    final row = Book(
      id: 'id-1',
      title: 'Alice',
      author: 'Carroll',
      language: 'en',
      filePath: '/p/alice.epub',
      storageMode: 'managed',
      coverPath: '/c/alice.png',
      addedAt: DateTime(2026, 6, 20),
      lastReadAt: null,
      fileSizeBytes: 12345,
    );
    final book = BookModel.fromRow(row);
    expect(book.id, 'id-1');
    expect(book.title, 'Alice');
    expect(book.author, 'Carroll');
    expect(book.coverPath, '/c/alice.png');
    expect(book.isUnread, isTrue);
  });

  test('BookModel without lastReadAt is unread', () {
    final book = BookModel(
      id: 'x',
      title: 't',
      author: null,
      language: null,
      filePath: '/x',
      storageMode: 'managed',
      coverPath: null,
      addedAt: DateTime.now(),
      lastReadAt: null,
      fileSizeBytes: null,
    );
    expect(book.isUnread, isTrue);
  });
}
