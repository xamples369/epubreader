import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/canonical_chapter_text.dart';

void main() {
  Future<EpubBook> loadFixture(String name) async {
    final bytes = await File('test/fixtures/$name').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  test('Test 10: extract is deterministic — two calls return identical string',
      () async {
    final book = await loadFixture('alice.epub');
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final a = CanonicalChapterText.extract(book, chapterId);
    final b = CanonicalChapterText.extract(book, chapterId);

    expect(a, equals(b));
    expect(a.length, greaterThan(100));
  });

  test('Test 11: extract works on all 4 fixtures, output is non-trivial',
      () async {
    for (final name in [
      'alice.epub',
      'pride.epub',
      'frankenstein.epub',
      'divina.epub',
    ]) {
      final book = await loadFixture(name);
      final chapters = book.Chapters ?? [];
      expect(chapters, isNotEmpty, reason: '$name has no chapters');
      final firstId = chapters.first.ContentFileName ?? '#0';
      final text = CanonicalChapterText.extract(book, firstId);
      expect(text.length, greaterThan(100),
          reason: '$name first chapter normalised text too short');
      expect(text, isNot(contains('<')),
          reason: '$name has unstripped HTML tags');
    }
  });

  test('extract returns empty string for missing chapterId', () async {
    final book = await loadFixture('alice.epub');
    final text = CanonicalChapterText.extract(book, 'NONEXISTENT.xhtml');
    expect(text, isEmpty);
  });

  test('extract supports #spineIndex fallback', () async {
    final book = await loadFixture('alice.epub');
    final text = CanonicalChapterText.extract(book, '#0');
    expect(text.length, greaterThan(100));
  });

  test('extract normalises typographic punctuation', () async {
    final book = await loadFixture('alice.epub');
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final text = CanonicalChapterText.extract(book, chapterId);
    // Žiadne smart quotes / em-dashes / ellipsis chars
    expect(text, isNot(contains('“')));
    expect(text, isNot(contains('”')));
    expect(text, isNot(contains('‘')));
    expect(text, isNot(contains('’')));
    expect(text, isNot(contains('—')));
    expect(text, isNot(contains('–')));
    expect(text, isNot(contains('…')));
  });
}
