import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart';

import '../anchor/canonical_chapter_text.dart';

/// Deterministický content-based identifikátor knihy.
///
/// SHA-256 hex (64 znakov) z normalizovaného obsahu:
/// - title (lowercase, trim)
/// - authors (zoznam, lowercase, trim, oddelený `|`)
/// - primary language
/// - kanonický text všetkých kapitol cez `CanonicalChapterText` (single source
///   of truth — rovnaký normalize ako anchor format z M2.5)
///
/// Stabilný cez re-zip toho istého obsahu (ignoruje ZIP timestamps).
/// Rôzny pre rôzne vydania (iný preklad, doplnené kapitoly).
/// Pozn.: ignoruje obálku (cover image) — kniha s rovnakým textom a novou
/// obálkou má rovnaký hash. Akceptovaná limitácia.
///
/// Detail: viď `docs/specs/m2.6-book-identity.md` a `docs/adr/0003-book-identity.md`.
class BookIdentity {
  BookIdentity._();

  /// Vráti 64-char hex SHA-256 hash. Nikdy nevyhadzuje výnimku.
  static String compute(EpubBook book) {
    final input = _canonicalInput(book);
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString();
  }

  static String _canonicalInput(EpubBook book) {
    final parts = <String>[];

    parts.add('TITLE:${_norm(book.Title ?? '')}');

    final authors = <String>[];
    final list = book.AuthorList;
    if (list != null && list.isNotEmpty) {
      for (final a in list) {
        if (a != null && a.isNotEmpty) authors.add(_norm(a));
      }
    } else if (book.Author != null && book.Author!.isNotEmpty) {
      authors.add(_norm(book.Author!));
    }
    parts.add('AUTHORS:${authors.join("|")}');

    parts.add('LANG:${_primaryLanguage(book) ?? ''}');

    final chapters = book.Chapters ?? [];
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final chapterId = chapter.ContentFileName ?? '#$i';
      final text = CanonicalChapterText.extract(book, chapterId);
      parts.add('CHAPTER:$chapterId:$text');
    }

    return parts.join('\n');
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static String? _primaryLanguage(EpubBook book) {
    final langs = book.Schema?.Package?.Metadata?.Languages;
    if (langs == null) return null;
    for (final l in langs) {
      if (l.isNotEmpty) return l.toLowerCase();
    }
    return null;
  }
}
