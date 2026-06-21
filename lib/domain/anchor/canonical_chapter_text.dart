import 'package:epubx/epubx.dart';

/// Jediný zdroj pravdy o normalizovanom texte kapitoly.
/// Používa OBE `AnchorCodec.createHighlight` AJ `findHighlight`, aby anchor
/// vytvorený proti tomuto textu sa proti nemu aj resolvol — žiadne divergence
/// medzi render-text a parse-text streammi.
///
/// Normalizácia zahŕňa:
///   1. Strip HTML tagov a najbežnejších entít
///   2. Strip soft hyphens (U+00AD)
///   3. Reconciliation typografickej punktuácie (smart quotes, em/en dash,
///      ellipsis) — variantné kódovania tej istej sémantiky sa zlúčia,
///      aby ručne písaná fráza používateľa zodpovedala publisher-formátovanému
///      textu v EPUB-e (objavené v S0 GATE).
///   4. Whitespace collapse + trim.
class CanonicalChapterText {
  CanonicalChapterText._();

  /// Vráti normalizovaný text kapitoly identifikovanej `chapterId`.
  /// `chapterId` je buď `ContentFileName` (manifest href) alebo `#<spineIndex>`.
  /// Pre neznámy chapterId vráti prázdny string.
  static String extract(EpubBook book, String chapterId) {
    final chapters = book.Chapters ?? [];
    EpubChapter? match;

    if (chapterId.startsWith('#')) {
      final idx = int.tryParse(chapterId.substring(1));
      if (idx != null && idx >= 0 && idx < chapters.length) {
        match = chapters[idx];
      }
    } else {
      for (final ch in chapters) {
        if (ch.ContentFileName == chapterId) {
          match = ch;
          break;
        }
      }
    }

    if (match == null) return '';

    final html = match.HtmlContent ?? '';
    final stripped = _stripHtml(html);
    return _normalize(stripped);
  }

  static String _stripHtml(String html) {
    final noTags = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  static String _normalize(String text) {
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
}
