import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';
import 'package:epubreader/domain/anchor/canonical_chapter_text.dart';

void main() {
  Future<EpubBook> loadAlice() async {
    final bytes = await File('test/fixtures/alice.epub').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  test('Test 1 (create part): createHighlight returns HighlightAnchor with quote',
      () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Nájdime ľubovoľný 30-znakový alfanumerický úsek bez whitespace na
    // boundaries (aby trim nezmenil dĺžku). Hľadáme 'Alice' a vezmeme následných
    // 30 znakov bez koncovej medzery.
    final aliceIdx = canonical.indexOf('Alice');
    expect(aliceIdx, greaterThan(-1),
        reason: 'alice fixture should contain the word Alice');

    final quote = canonical.substring(aliceIdx, aliceIdx + 30).trimRight();
    final knownStart = aliceIdx;
    final prefixStart = (knownStart - 20).clamp(0, canonical.length);
    final suffixEnd =
        (knownStart + quote.length + 20).clamp(0, canonical.length);
    final realPrefix = canonical.substring(prefixStart, knownStart);
    final realSuffix =
        canonical.substring(knownStart + quote.length, suffixEnd);

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: quote,
      rawPrefix: realPrefix,
      rawSuffix: realSuffix,
    );

    expect(anchor.chapterId, chapterId);
    expect(anchor.quote, quote);
    // charOffset môže byť ±1 kvôli prefix/suffix trim, ale musí byť veľmi blízko
    expect(anchor.charOffset, isNotNull);
    expect((anchor.charOffset! - knownStart).abs(), lessThan(5));
  });

  test('Test 7: long selection gets capped at 200 chars', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final longSelection = 'x' * 300;
    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: longSelection,
      rawPrefix: '',
      rawSuffix: '',
    );

    expect(anchor.quote.length, 200);
    expect(anchor.charOffset, isNull); // 'xxx...' nie je v alice texte
  });

  test('createHighlight caps prefix/suffix at 32 chars', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: 'word',
      rawPrefix: 'long' * 20, // 80 znakov
      rawSuffix: 'tail' * 20,
    );

    expect(anchor.prefix.length, 32);
    expect(anchor.suffix.length, 32);
  });

  test('createHighlight with text not in canonical → charOffset null', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: 'absolutely_not_in_alice_qwxyz123',
      rawPrefix: 'never',
      rawSuffix: 'ever',
    );

    expect(anchor.charOffset, isNull);
  });
}
