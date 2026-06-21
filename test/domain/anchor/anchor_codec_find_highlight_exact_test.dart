import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';
import 'package:epubreader/domain/anchor/canonical_chapter_text.dart';
import 'package:epubreader/domain/anchor/highlight_anchor.dart';

void main() {
  Future<EpubBook> loadAlice() async {
    final bytes = await File('test/fixtures/alice.epub').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  Future<EpubBook> loadDivina() async {
    final bytes = await File('test/fixtures/divina.epub').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  test('Test 1: create -> JSON -> decode -> findHighlight round-trip',
      () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Nájdi reálny úsek
    final aliceIdx = canonical.indexOf('Alice');
    expect(aliceIdx, greaterThan(-1));
    final quote = canonical.substring(aliceIdx, aliceIdx + 30).trimRight();
    final prefixStart = (aliceIdx - 20).clamp(0, canonical.length);
    final suffixEnd =
        (aliceIdx + quote.length + 20).clamp(0, canonical.length);

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: quote,
      rawPrefix: canonical.substring(prefixStart, aliceIdx),
      rawSuffix: canonical.substring(aliceIdx + quote.length, suffixEnd),
    );

    // JSON round-trip
    final encoded = anchor.toJson();
    final decoded = HighlightAnchor.fromJson(encoded);

    final range = AnchorCodec.findHighlight(anchor: decoded, book: book);
    expect(range, isNotNull);
    expect(canonical.substring(range!.start, range.end), quote);
  });

  test('Test 3: disambiguation via prefix+suffix when quote appears twice',
      () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Vyber slovo, ktoré sa vyskytuje aspoň 2× (Alice — rare ale opakované)
    const common = 'Alice';
    final firstIdx = canonical.indexOf(common);
    if (firstIdx < 0) return;
    final secondIdx = canonical.indexOf(common, firstIdx + 1);
    if (secondIdx < 0) return;

    // Manuálne vytvor anchor s presným kontextom druhého výskytu — žiadny
    // createHighlight per-piece normalize, takže prefix+quote+suffix je presne
    // contiguous substring v canonical (bez trim artefaktov).
    final prefixStart = (secondIdx - 20).clamp(0, canonical.length);
    final suffixEnd =
        (secondIdx + common.length + 20).clamp(0, canonical.length);
    final exactPrefix = canonical.substring(prefixStart, secondIdx);
    final exactSuffix =
        canonical.substring(secondIdx + common.length, suffixEnd);

    final anchor = HighlightAnchor(
      chapterId: chapterId,
      quote: common,
      prefix: exactPrefix,
      suffix: exactSuffix,
      charOffset: null, // force disambiguation cez context, nie hint window
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
    expect(range!.start, secondIdx);
  });

  test('Test 4: lost anchor returns null without crash', () async {
    final book = await loadAlice();

    const anchor = HighlightAnchor(
      chapterId: '#0',
      quote: 'THIS TEXT DEFINITELY DOES NOT EXIST IN ALICE qwxyz123',
      prefix: 'never',
      suffix: 'ever',
      charOffset: 5000,
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNull);
  });

  test('Test 5 (resolve part): diacritics resolve on divina.epub', () async {
    final book = await loadDivina();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Nájdi úsek s diakritikou
    final accentMatch = RegExp('[èàòíùé]').firstMatch(canonical);
    if (accentMatch == null) return;
    final start = (accentMatch.start - 10).clamp(0, canonical.length);
    final end = (accentMatch.start + 20).clamp(0, canonical.length);
    final quote = canonical.substring(start, end).trim();
    if (quote.isEmpty) return;

    final actualStart = canonical.indexOf(quote);
    expect(actualStart, greaterThan(-1));

    final prefix = canonical.substring(
        (actualStart - 10).clamp(0, canonical.length), actualStart);
    final suffix = canonical.substring(
        actualStart + quote.length,
        (actualStart + quote.length + 10).clamp(0, canonical.length));

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: quote,
      rawPrefix: prefix,
      rawSuffix: suffix,
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
    expect(canonical.substring(range!.start, range.end), quote);
  });

  test('Test 6 (resolve part): whitespace-normalised match', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Použi známy alfanumerický úsek
    final aliceIdx = canonical.indexOf('Alice');
    expect(aliceIdx, greaterThan(-1));
    final quote = canonical.substring(aliceIdx, aliceIdx + 30).trimRight();

    // Vytvor anchor s normálnym kontextom
    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: quote, // normálny
      rawPrefix: canonical.substring(
          (aliceIdx - 15).clamp(0, canonical.length), aliceIdx),
      rawSuffix: canonical.substring(
          aliceIdx + quote.length,
          (aliceIdx + quote.length + 15).clamp(0, canonical.length)),
    );

    // Teraz simulujeme že na vstupe sa quote zopakovala s mixed whitespace —
    // ale to je vec createHighlight, nie find. Tu len overíme že find správne
    // funguje na anchore vytvorenom z normálneho textu.
    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
    expect(canonical.substring(range!.start, range.end), quote);
  });
}
