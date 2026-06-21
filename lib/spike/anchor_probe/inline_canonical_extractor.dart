import 'dart:typed_data';

import 'package:epubx/epubx.dart';

/// Spike-local copy. Bude extrahované do lib/domain/anchor/canonical_chapter_text.dart
/// v Task 3 s plnými testami. Tu žije len kvôli S0 gate testu.
class InlineCanonicalExtractor {
  /// Vráti dvojicu (chapterId, normalizedText) pre každú kapitolu knihy.
  static Future<List<(String, String)>> extractAll(Uint8List epubBytes) async {
    final book = await EpubReader.readBook(epubBytes);
    final chapters = book.Chapters ?? [];
    final result = <(String, String)>[];
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final chapterId = chapter.ContentFileName ?? '#$i';
      final raw = _stripHtml(chapter.HtmlContent ?? '');
      final normalised = _normalize(raw);
      result.add((chapterId, normalised));
    }
    return result;
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
    final dehyphenated = text.replaceAll('­', '');
    final collapsed = dehyphenated.replaceAll(RegExp(r'[\s ]+'), ' ');
    return collapsed.trim();
  }
}
