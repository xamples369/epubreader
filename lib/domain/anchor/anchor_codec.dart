import 'package:epubx/epubx.dart';

import 'anchor_range.dart';
import 'canonical_chapter_text.dart';
import 'highlight_anchor.dart';

/// Encoder / decoder anchorov + resolve algoritmus.
/// Doménová vrstva — bez Flutter / Drift importov.
class AnchorCodec {
  AnchorCodec._();

  /// Normalize text pre konzistentné porovnávanie.
  ///
  /// - Strip soft hyphens (U+00AD)
  /// - Typographic punctuation reconciliation (smart quotes → straight,
  ///   em/en dash → hyphen, ellipsis → three dots)
  /// - Whitespace collapse (vrátane \t, \n, nbsp) → single space
  /// - Trim
  ///
  /// MUSÍ byť synchronizované s `CanonicalChapterText._normalize` — obe strany
  /// porovnávania (uložený anchor vs aktuálny text) musia prejsť rovnakou
  /// normalizáciou, inak exact match zlyhá aj keď text reálne sedí.
  static String normalize(String text) {
    var t = text.replaceAll('­', ''); // soft hyphen U+00AD
    t = t
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('„', '"')
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('‚', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...');
    final collapsed = t.replaceAll(RegExp(r'[\s ]+'), ' ');
    return collapsed.trim();
  }

  /// Vytvorí `HighlightAnchor` zo selekcie + okolitého kontextu.
  /// String-first prístup — žiadne offset mapping medzi raw a normalised textom.
  /// `book + chapterId` slúžia na získanie KANONICKÉHO textu kapitoly (§4.5
  /// spec-u) — toto je single source of truth aj pre `findHighlight`.
  static HighlightAnchor createHighlight({
    required EpubBook book,
    required String chapterId,
    required String rawSelectedText,
    required String rawPrefix,
    required String rawSuffix,
  }) {
    final canonical = CanonicalChapterText.extract(book, chapterId);

    final quote = normalize(rawSelectedText);
    final prefix = normalize(rawPrefix);
    final suffix = normalize(rawSuffix);

    final cappedQuote = quote.length > 200 ? quote.substring(0, 200) : quote;
    final cappedPrefix =
        prefix.length > 32 ? prefix.substring(prefix.length - 32) : prefix;
    final cappedSuffix =
        suffix.length > 32 ? suffix.substring(0, 32) : suffix;

    // charOffset je len HINT — hľadáme v KANONICKOM texte.
    int? charOffset;
    final hintNeedle = cappedPrefix + cappedQuote + cappedSuffix;
    if (hintNeedle.isNotEmpty && canonical.isNotEmpty) {
      final hintMatch = canonical.indexOf(hintNeedle);
      if (hintMatch >= 0) {
        charOffset = hintMatch + cappedPrefix.length;
      }
    }

    return HighlightAnchor(
      chapterId: chapterId,
      quote: cappedQuote,
      prefix: cappedPrefix,
      suffix: cappedSuffix,
      charOffset: charOffset,
    );
  }

  /// Resolve `HighlightAnchor` na `AnchorRange` v kanonickom texte kapitoly.
  /// Algoritmus per spec §5:
  ///   1. Normalize chapter (cez CanonicalChapterText.extract — už normalised)
  ///   2. Exact match v okne ±200 znakov okolo charOffset hint-u
  ///   3. Single hit v okne → vráť
  ///   4. Viac hitov / žiadny v okne → skús prefix+quote+suffix presný kontext
  ///   5. Global single exact match
  ///   6. (Task 7) Sliding fuzzy fallback
  ///   7. Inak null
  static AnchorRange? findHighlight({
    required HighlightAnchor anchor,
    required EpubBook book,
  }) {
    final canonical = CanonicalChapterText.extract(book, anchor.chapterId);
    if (canonical.isEmpty || anchor.quote.isEmpty) return null;

    // (2) Exact match v okne ±200 okolo charOffset
    final hint = anchor.charOffset;
    if (hint != null) {
      final windowStart = (hint - 200).clamp(0, canonical.length);
      final windowEnd =
          (hint + 200 + anchor.quote.length).clamp(0, canonical.length);
      if (windowEnd > windowStart) {
        final window = canonical.substring(windowStart, windowEnd);
        final localIdx = window.indexOf(anchor.quote);
        // (3) Single hit v okne?
        if (localIdx >= 0 &&
            window.indexOf(anchor.quote, localIdx + 1) < 0) {
          return AnchorRange(
            windowStart + localIdx,
            windowStart + localIdx + anchor.quote.length,
          );
        }
      }
    }

    // (4) Disambiguácia cez prefix+quote+suffix presný kontext
    final contextNeedle = anchor.prefix + anchor.quote + anchor.suffix;
    if (contextNeedle.length > anchor.quote.length) {
      final contextIdx = canonical.indexOf(contextNeedle);
      if (contextIdx >= 0) {
        final quoteStart = contextIdx + anchor.prefix.length;
        return AnchorRange(quoteStart, quoteStart + anchor.quote.length);
      }
    }

    // (5) Global single exact match (žiadne okno, žiadny kontext)
    final globalIdx = canonical.indexOf(anchor.quote);
    if (globalIdx >= 0 && canonical.indexOf(anchor.quote, globalIdx + 1) < 0) {
      return AnchorRange(globalIdx, globalIdx + anchor.quote.length);
    }

    // (6) Sliding fuzzy fallback — implementuje sa v T7
    return null;
  }
}
