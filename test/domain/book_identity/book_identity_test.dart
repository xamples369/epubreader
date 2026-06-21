import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/book_identity/book_identity.dart';

void main() {
  Future<EpubBook> loadFixture(String name) async {
    final bytes = await File('test/fixtures/$name').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  test('compute is deterministic — two calls return identical hash', () async {
    final book = await loadFixture('alice.epub');
    final a = BookIdentity.compute(book);
    final b = BookIdentity.compute(book);
    expect(a, equals(b));
  });

  test('output format is 64-char lowercase hex', () async {
    final book = await loadFixture('alice.epub');
    final hash = BookIdentity.compute(book);
    expect(hash.length, 64);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
  });

  test('all 4 fixtures produce unique hashes', () async {
    final hashes = <String>{};
    for (final name in [
      'alice.epub',
      'pride.epub',
      'frankenstein.epub',
      'divina.epub',
    ]) {
      final book = await loadFixture(name);
      hashes.add(BookIdentity.compute(book));
    }
    expect(hashes.length, 4,
        reason: '4 different fixtures should produce 4 different hashes');
  });

  test('hash is stable across re-load of the same file', () async {
    final bytes = await File('test/fixtures/alice.epub').readAsBytes();
    final book1 = await EpubReader.readBook(bytes);
    final book2 = await EpubReader.readBook(bytes);

    final hash1 = BookIdentity.compute(book1);
    final hash2 = BookIdentity.compute(book2);
    expect(hash1, equals(hash2));
  });

  test('compute does not throw for book with no chapters', () {
    final empty = EpubBook()
      ..Title = 'Empty Book'
      ..Author = 'Anonymous'
      ..AuthorList = ['Anonymous']
      ..Chapters = [];
    final hash = BookIdentity.compute(empty);
    expect(hash.length, 64);
  });

  test('compute does not throw for book without metadata', () {
    final naked = EpubBook()..Chapters = [];
    final hash = BookIdentity.compute(naked);
    expect(hash.length, 64);
  });

  test('two books with different titles produce different hashes', () {
    final a = EpubBook()
      ..Title = 'Book A'
      ..Author = 'Same'
      ..AuthorList = ['Same']
      ..Chapters = [];
    final b = EpubBook()
      ..Title = 'Book B'
      ..Author = 'Same'
      ..AuthorList = ['Same']
      ..Chapters = [];
    expect(BookIdentity.compute(a), isNot(equals(BookIdentity.compute(b))));
  });
}
