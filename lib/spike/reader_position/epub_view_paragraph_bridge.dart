// SOLE point of contact with epub_view's internal parsing code.
//
// **All other code must access paragraph data through this bridge.**
//
// WHY src/ import?
// - epub_view 3.2.0 does not expose flatParagraphs / paragraph text via
//   public API. The `_paragraphs` list lives in `_EpubViewState` as a private
//   field. `EpubController` exposes only chapter/paragraph numbers + position,
//   not the parsed Paragraph objects themselves.
// - `parseChapters` and `parseParagraphs` ARE top-level public functions in
//   `package:epub_view/src/data/epub_parser.dart`. Calling them ourselves
//   with the same EpubBook produces a byte-identical `flatParagraphs` list
//   to what `_EpubViewState` builds internally (alignment by construction).
// - "Reimplement our own segmenter" alternative would silently drift on
//   epub_view upgrades. Calling the same function = loud failure
//   (compile error on signature change, alignment probe fail on behaviour
//   change).
//
// RULES (per ADR 0005 — Vetva 1.5 acceptance):
// 1. epub_view version is **pinned** (not caret) in pubspec.yaml.
// 2. Any epub_view version bump requires alignment probe re-run before merge.
// 3. Permanent regression test (production T2+) verifies equivalence against
//    `EpubController.tableOfContents()` startIndex per chapter on all 4
//    fixtures — catches internal post-processing drift.
// 4. Single blast radius: if epub_view eventually exposes a public API for
//    flatParagraphs, only this file changes. See memory note
//    `project_epub_view_upstream_issue.md` for cleanup follow-up.
//
// ignore_for_file: implementation_imports

import 'package:epub_view/src/data/epub_parser.dart';

/// Adapter ktorý získa `flatParagraphs` zoznam zhodný s tým aký si EpubView
/// vyrobí interne pri otvorení tej istej knihy.
class EpubViewParagraphBridge {
  EpubViewParagraphBridge._();

  /// Volá `parseChapters` (zahŕňa SubChapters cez fold) + `parseParagraphs`
  /// (rovnaký segmentation algoritmus ako `_EpubViewState`).
  ///
  /// Vráti `ParseParagraphsResult` ktorý obsahuje:
  ///   - `flatParagraphs: List<Paragraph>` — všetky paragraphs naprieč
  ///     kapitolami v poradí. `Paragraph.element` je html DOM element;
  ///     `.text` na ňom dá čistý text odseku.
  ///   - `chapterIndexes: List<int>` — absolute offsets v flatParagraphs
  ///     kde každá kapitola začína. Musí byť rovnaký ako
  ///     `EpubController.tableOfContents()[i].startIndex` (equivalence
  ///     probe v `reader_position_probe_screen.dart`).
  static ParseParagraphsResult extractFlatParagraphs(EpubBook book) {
    final chapters = parseChapters(book);
    return parseParagraphs(chapters, book.Content);
  }
}
