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

  test('schemeVersion constant exists and is 1', () {
    expect(BookIdentity.schemeVersion, 1);
  });

  test('canonical input starts with SCHEME:<version> prefix', () async {
    final book = await loadFixture('alice.epub');
    final input = BookIdentity.debugCanonicalInput(book);
    expect(input, startsWith('SCHEME:1\n'));
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
    expect(BookIdentity.compute(book1), equals(BookIdentity.compute(book2)));
  });

  test('compute does not throw for empty book', () {
    final empty = EpubBook();
    final hash = BookIdentity.compute(empty);
    expect(hash.length, 64);
  });

  test(
      'spine iteration covers full book — divina has rich text (>200K chars)',
      () async {
    // Divina Commedia = 3 cantiche × ~33 cantos = ~100 spine items.
    // Each canto ~3000+ chars text. Total well over 200K.
    // Pôvodný (chyba) hash cez book.Chapters by vrátil len top-level
    // Inferno/Purgatorio/Paradiso obalom — drasticky menej.
    final book = await loadFixture('divina.epub');
    final input = BookIdentity.debugCanonicalInput(book);
    // Subtract scheme line + ITEM: prefixes; rough lower bound
    expect(input.length, greaterThan(200000),
        reason:
            'Divina canonical input length should reflect full ~100-canto coverage; '
            'if short, spine iteration is broken or href resolution failing');
  });

  test(
      'spine iteration covers full book — alice has reasonable text (>50K chars)',
      () async {
    final book = await loadFixture('alice.epub');
    final input = BookIdentity.debugCanonicalInput(book);
    expect(input.length, greaterThan(50000),
        reason:
            'Alice in Wonderland is a short book but still >50K chars of text');
  });

  test('canonical input is content-only — no TITLE/AUTHORS/LANG markers',
      () async {
    final book = await loadFixture('alice.epub');
    final input = BookIdentity.debugCanonicalInput(book);
    expect(input, isNot(contains('TITLE:')));
    expect(input, isNot(contains('AUTHORS:')));
    expect(input, isNot(contains('LANG:')));
  });
}
