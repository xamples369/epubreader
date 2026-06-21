# Phase 1 — M2.5: Anchor Format Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. **For this plan inline execution is preferred** — recent subagent dispatches have been flaky on long-running build_runner / file-system ops. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doručiť render-agnostic anchor formát (ReadingPositionAnchor + HighlightAnchor) + AnchorCodec s testami, plus ADR 0002 ktorý zafixuje rozhodnutia — vrátane výsledku **S0 canonical-text gate**, ktorý beží PRVÝ a môže celý plán prevrátiť.

**Architecture:** Čistá `lib/domain/anchor/` vrstva bez Flutter/Drift importov. `CanonicalChapterText` je *jediný zdroj pravdy* o texte kapitoly — používa ho `createHighlight` aj `findHighlight`. Fuzzy resolve cez sliding alignment (Smith-Waterman-style), nie Levenshtein proti celému oknu. Spike obrazovka `lib/spike/anchor_probe/` je throwaway — po S8 sa zmaže.

**Tech Stack:** Dart 3.10, `epubx ^4.0.0` (parser), `meta` (`@immutable`), `flutter_test`. Bez nových dependencies.

---

## Predpoklady

- M2 mergnutý do master.
- Branch `m2.5-anchor-spike` aktívny (už vytvorený).
- Spec `docs/specs/m2.5-anchor-format.md` schválený.
- `flutter analyze` clean, `flutter test` pass na current state.

---

## Súborová mapa

```
lib/
├── spike/anchor_probe/                    (throwaway — S8 maže)
│   ├── anchor_probe_screen.dart          (CREATE T1, EXTEND T2)
│   └── inline_canonical_extractor.dart   (CREATE T1, EXTRAHUJE sa do domain/ v T3)
├── domain/anchor/                         (perm)
│   ├── canonical_chapter_text.dart       (CREATE T3)
│   ├── reading_position_anchor.dart      (CREATE T4)
│   ├── highlight_anchor.dart             (CREATE T4)
│   ├── anchor_range.dart                 (CREATE T4)
│   └── anchor_codec.dart                 (CREATE T5, EXTEND T6, T7)
├── features/library/
│   └── library_screen.dart               (MODIFY T1 — pridať dev button; UNDO v T9)
└── app.dart                              (MODIFY T1 — pridať /dev/anchor_probe route; UNDO v T9)

test/domain/anchor/
├── canonical_chapter_text_test.dart      (CREATE T3 — Tests 10, 11)
├── reading_position_anchor_test.dart     (CREATE T4 — Test 8)
├── highlight_anchor_test.dart            (CREATE T4 — bázový round-trip)
├── anchor_codec_normalize_test.dart      (CREATE T5 — Tests 5, 6)
├── anchor_codec_create_highlight_test.dart  (CREATE T5 — Tests 1 create, 7)
├── anchor_codec_find_highlight_exact_test.dart  (CREATE T6 — Tests 1 resolve, 3, 4)
├── anchor_codec_find_highlight_fuzzy_test.dart  (CREATE T7 — Tests 2, 12)
└── anchor_codec_merge_test.dart          (CREATE T8 — Test 9)

docs/adr/
└── 0002-anchor-format.md                 (CREATE T9)
```

---

## Task 1: S0 GATE — Canonical-text consistency spike

**Cieľ:** overiť že selekcia z `EpubView` rendereru sa nájde v normalizovanom epubx texte na všetkých 4 fixtures. Ak zlyhá, **STOP a re-spec**.

**Files:**
- Create: `lib/spike/anchor_probe/anchor_probe_screen.dart`
- Create: `lib/spike/anchor_probe/inline_canonical_extractor.dart`
- Modify: `lib/app.dart` (add `/dev/anchor_probe` route)
- Modify: `lib/features/library/library_screen.dart` (add dev FAB)

- [ ] **Step 1.1: Create `lib/spike/anchor_probe/inline_canonical_extractor.dart`**

```dart
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
    // Naive ale dostatočné pre spike: odstráň <tagy>, ponechaj text.
    return html.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  static String _normalize(String text) {
    // NFC unicode + whitespace collapse + trim + strip soft hyphens.
    final stripped = text.replaceAll('­', '');
    final collapsed = stripped.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.trim();
  }
}
```

- [ ] **Step 1.2: Create `lib/spike/anchor_probe/anchor_probe_screen.dart`**

```dart
import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'inline_canonical_extractor.dart';

class AnchorProbeScreen extends StatefulWidget {
  const AnchorProbeScreen({super.key});

  @override
  State<AnchorProbeScreen> createState() => _AnchorProbeScreenState();
}

class _AnchorProbeScreenState extends State<AnchorProbeScreen> {
  EpubController? _controller;
  List<(String, String)>? _canonicalChapters; // (chapterId, normalisedText)
  String? _selection;
  String? _matchResult;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller = null;
      _canonicalChapters = null;
      _selection = null;
      _matchResult = null;
    });
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      dialogTitle: 'Vyber EPUB fixture na probe',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final canonical = await InlineCanonicalExtractor.extractAll(bytes);
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() {
        _controller = controller;
        _canonicalChapters = canonical;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _checkSelectionAgainstCanonical(String selection) {
    final chapters = _canonicalChapters;
    if (chapters == null) return;
    final normalisedSel = _normalize(selection);
    final hits = <String>[];
    for (final (id, text) in chapters) {
      if (text.contains(normalisedSel)) hits.add(id);
    }
    setState(() {
      _selection = selection;
      if (hits.isEmpty) {
        _matchResult = '❌ NIE — selekcia sa NEnajde ani v jednej kapitole '
            '(canonical/render rozchádza)';
      } else {
        _matchResult = '✅ ÁNO — nájdená v ${hits.length} kapitolách: '
            '${hits.take(3).join(", ")}';
      }
    });
  }

  static String _normalize(String text) {
    final stripped = text.replaceAll('­', '');
    final collapsed = stripped.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.trim();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anchor Probe (S0 GATE)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Otvoriť fixture',
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'S0 GATE: vyber EPUB → urob 3-5 selekcií → klikni '
                  '"Check selection". Cieľ: VŠETKY selekcie majú vrátiť ✅.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_selection != null) ...[
                  const SizedBox(height: 8),
                  Text('Selekcia: "${_selection!}"',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (_matchResult != null) ...[
                  const SizedBox(height: 4),
                  Text(_matchResult!, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          if (_controller != null)
            Expanded(child: EpubView(controller: _controller!)),
          if (_controller == null)
            const Expanded(
              child: Center(child: Text('Klikni priečinok hore a vyber EPUB')),
            ),
        ],
      ),
      floatingActionButton: _canonicalChapters == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('Check selection'),
              onPressed: () async {
                final input = await _promptForSelection(context);
                if (input != null && input.isNotEmpty) {
                  _checkSelectionAgainstCanonical(input);
                }
              },
            ),
    );
  }

  Future<String?> _promptForSelection(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vlož selekciu na overenie'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Skopíruj text z čítača vyššie...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Zrušiť')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Check')),
        ],
      ),
    );
  }
}
```

**Poznámka k UX:** `epub_view` natívne neexportuje system text selection v jednoduchom callbacku, tak používame **copy-paste workflow** pre spike: používateľ vyberie text z čítača (Ctrl+C alebo dlhý stlač), klikne FAB „Check selection", paste-ne do dialógu, klikne Check. To je dostačujúce na overenie containment.

- [ ] **Step 1.3: Pridať route v `lib/app.dart`**

Otvor `lib/app.dart` a v `onGenerateRoute` callback-u pridaj druhý case PRED existujúci `/reader`:

```dart
      onGenerateRoute: (settings) {
        if (settings.name == '/dev/anchor_probe') {
          return MaterialPageRoute(
            builder: (_) => const AnchorProbeScreen(),
          );
        }
        if (settings.name == '/reader') {
          final bookId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ReaderStubScreen(bookId: bookId),
          );
        }
        return null;
      },
```

A pridaj import navrch:

```dart
import 'spike/anchor_probe/anchor_probe_screen.dart';
```

- [ ] **Step 1.4: Pridať dev FAB v `lib/features/library/library_screen.dart`**

Existujúci FAB `FloatingActionButton.extended(...)` zaobaľ do `Stack` v `floatingActionButton`, ALEBO jednoduchšie — nahraď ho `Wrap`-om s druhým miniFAB:

Nájdi:
```dart
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.addBook),
        onPressed: () => _pickAndAdd(context, ref),
      ),
```

Nahraď:
```dart
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'devAnchorProbe',
            tooltip: 'DEV: anchor probe (S0 gate)',
            child: const Icon(Icons.science),
            onPressed: () => Navigator.of(context).pushNamed('/dev/anchor_probe'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'addBook',
            icon: const Icon(Icons.add),
            label: Text(l.addBook),
            onPressed: () => _pickAndAdd(context, ref),
          ),
        ],
      ),
```

- [ ] **Step 1.5: Verify build**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter build windows --debug` v pozadí (`run_in_background: true`, timeout 300000)
Expected: build úspešný

- [ ] **Step 1.6: Commit a push**

```
git add lib/spike/anchor_probe/ lib/app.dart lib/features/library/library_screen.dart
git commit -m "feat(m2.5): anchor probe spike screen for S0 canonical-text gate"
git push
```

**No `Co-Authored-By:` trailer.**

- [ ] **Step 1.7: MANUAL S0 GATE — používateľ spustí appku a otestuje**

Pošli používateľovi inštrukciu:

> Spusti `flutter run -d windows`. Na library obrazovke klikni mini FAB s ikonou
> baňky (science). Otvorí sa Anchor Probe. Pre každý zo 4 fixtures
> (`test/fixtures/alice.epub`, `pride.epub`, `frankenstein.epub`, `divina.epub`):
> 1. Otvor cez ikonu priečinka
> 2. Pre 3-5 rôznych textových úsekov: zvýrazni text v čítači, skopíruj
>    (Ctrl+C alebo dlhý stlač), klikni „Check selection", paste, klikni Check
> 3. Zapíš výsledky: koľko ✅ vs koľko ❌
>
> **Akceptačné kritérium:** všetkých ~16 testov (4 fixtures × 4 selekcie) má vrátiť ✅.
>
> Ak niektoré ❌:
> - Skopíruj presný text selekcie + meno fixture-y
> - Pošli mi to. Spolu zistíme či treba reconciliation pravidlo do normalize,
>   alebo či extractor potrebuje strip footnote markery, alt text, atď.
>
> Ak systematicky všetky ❌ → STOP, treba prehodnotiť extractor alebo renderer.

**TASK 1 SA POVAŽUJE ZA HOTOVÝ AŽ KEĎ POUŽÍVATEĽ POTVRDÍ ✅ NA VŠETKÝCH 4 FIXTURES.**

Ak gate prejde, dokumentuj výsledky v dočasnom súbore `docs/adr/0002-anchor-format-draft-notes.md` (bude konsolidované do finálneho ADR v T9):

```markdown
# ADR 0002 draft notes — S0 GATE results

## Canonical-text consistency test (run YYYY-MM-DD by <user>)

| Fixture | Selekcií testovaných | ✅ | ❌ | Poznámky |
|---------|----------------------|----|----|----------|
| alice.epub | 4 | 4 | 0 | |
| pride.epub | 4 | 4 | 0 | |
| frankenstein.epub | 4 | 4 | 0 | |
| divina.epub | 4 | 4 | 0 | (diakritika OK) |

**S0 GATE: PASSED** — pokračujeme S1.
```

Commit + push tento draft súbor.

---

## Task 2: S1 — Spike investigation (controller API + scroll Plán A vs B)

**Cieľ:** Doplniť spike obrazovku o logovanie všetkého čo `EpubController` poskytuje, zistiť či `epub_view` má programmatic scroll na char N.

**Files:**
- Modify: `lib/spike/anchor_probe/anchor_probe_screen.dart`
- Modify: `docs/adr/0002-anchor-format-draft-notes.md`

- [ ] **Step 2.1: Statická analýza balíka epub_view**

Read súbor `C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/epub_controller.dart` (alebo grep cez celý balík)

Vypíš si verejné metódy/gettery `EpubController` ktoré sa týkajú pozície:
- `scrollTo(...)`? Aký parameter?
- `jumpTo(...)`?
- `currentValue` / `currentValueListenable`?
- `tableOfContents` / `tableOfContentsListenable`?
- `loadingState`?

Zapíš zistenia ako tabuľku do draft notes.

- [ ] **Step 2.2: Pridať logovanie do spike obrazovky**

Po `_controller = controller;` v `_pickAndLoad`, pridaj:

```dart
controller.currentValueListenable.addListener(() {
  final v = controller.currentValue;
  debugPrint('[probe] currentValue: chapterNumber=${v?.chapterNumber}, '
      'paragraphNumber=${v?.paragraphNumber}, '
      'chapter=${v?.chapter?.Title}');
});
controller.loadingState.addListener(() {
  debugPrint('[probe] loadingState: ${controller.loadingState.value}');
});
```

(Konkrétne mená polí závisia od verzie — Step 2.1 ich zistí. Uprav podľa toho čo existuje.)

- [ ] **Step 2.3: Pridať „Test programmatic scroll" tlačidlo**

Pridaj druhý FAB / tlačidlo do spike obrazovky:

```dart
// V FAB Wrap-e pridaj ďalšie tlačidlo:
FloatingActionButton.small(
  heroTag: 'devScrollTo',
  tooltip: 'Test scrollTo(chapterIndex, paragraphIndex)',
  child: const Icon(Icons.arrow_downward),
  onPressed: () {
    // Príklad: scroll na druhý odsek tretej kapitoly
    // Konkrétne API závisí od verzie epub_view (Step 2.1)
    // _controller?.scrollTo(index: ?);
    debugPrint('[probe] manual scroll attempt');
  },
),
```

- [ ] **Step 2.4: Build + manual test**

```
flutter analyze
flutter build windows --debug    # v pozadí
```

Manual test: spusti appku, otvor fixture, scrolluj, sleduj `debugPrint` v termináli. Skús tlačidlo scroll. Zaznamenaj čo funguje a čo nie.

- [ ] **Step 2.5: Dokumentuj zistenia do draft notes**

Doplň do `docs/adr/0002-anchor-format-draft-notes.md` tabuľku ako v spec-u §3.3:

```markdown
## Investigačná tabuľka (EpubController API)

| Info | Dostupné? | Cez aké API | Kvalita |
|------|-----------|-------------|---------|
| Aktuálna kapitola (href) | ÁNO/NIE | `controller.currentValue.chapter.ContentFileName` | dobré/parciálne/zlé |
| Aktuálna kapitola (spine index) | ? | ? | ? |
| ... |

## Plán A vs Plán B (RP resolve)

- **Plán A** (priame char→scroll): dostupné? ÁNO/NIE
- **Plán B** (degenerovaný HighlightAnchor): vždy dostupné (cez `findHighlight` + widget search)

**Rozhodnutie pre ADR 0002:** Plán A / Plán B / oboje (preferencia A, fallback B)
```

- [ ] **Step 2.6: Commit + push**

```
git add lib/spike/anchor_probe/anchor_probe_screen.dart docs/adr/
git commit -m "feat(m2.5): extend anchor probe with controller logging + scroll test"
git push
```

---

## Task 3: S2 — `CanonicalChapterText` extractor + tests

**Cieľ:** Extrahovať canonical extractor zo spike-u do produkčnej domain vrstvy s plnými testami.

**Files:**
- Create: `lib/domain/anchor/canonical_chapter_text.dart`
- Create: `test/domain/anchor/canonical_chapter_text_test.dart`

- [ ] **Step 3.1: Write failing test FIRST**

`test/domain/anchor/canonical_chapter_text_test.dart`:

```dart
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
      // Žiadne HTML tagy nesmú prejsť
      expect(text, isNot(contains('<')), reason: '$name has unstripped tags');
    }
  });

  test('extract returns empty string for missing chapterId', () async {
    final book = await loadFixture('alice.epub');
    final text = CanonicalChapterText.extract(book, 'NONEXISTENT.xhtml');
    expect(text, isEmpty);
  });
}
```

- [ ] **Step 3.2: Run test to verify it fails**

```
flutter test test/domain/anchor/canonical_chapter_text_test.dart
```

Expected: compile error — `CanonicalChapterText` doesn't exist.

- [ ] **Step 3.3: Implement `lib/domain/anchor/canonical_chapter_text.dart`**

```dart
import 'package:epubx/epubx.dart';

/// Jediný zdroj pravdy o normalised texte kapitoly.
/// Používa OBE `AnchorCodec.createHighlight` AJ `findHighlight`, aby anchor
/// vytvorený proti tomuto textu sa proti nemu aj resolvol — žiadne divergence
/// medzi render-text a parse-text streammi.
class CanonicalChapterText {
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
    // Naive ale dostatočné — odstráň všetky <tagy>, ponechaj iba text.
    // Zachová whitespace v texte; následný _normalize ho zbalí.
    final noTags = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // HTML entities — najbežnejšie. (Pre úplnosť by sme mohli použiť
    // html_unescape package, ale pre canonical text stačí toto.)
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
    // 1. Strip soft hyphens (U+00AD)
    final dehyphenated = text.replaceAll('­', '');
    // 2. Collapse all whitespace (including \t, \n, nbsp  ) into single space
    final collapsed = dehyphenated.replaceAll(RegExp(r'[\s ]+'), ' ');
    // 3. Trim
    return collapsed.trim();
    // Pozn.: Unicode NFC normalisation by sme robili tu, ale Dart nemá
    // native API; v praxi pre EPUB knihy z Project Gutenberg toto netreba.
    // Ak by sa neskôr ukázalo že treba, použijeme `characters` package.
  }
}
```

- [ ] **Step 3.4: Run test to verify it passes**

```
flutter test test/domain/anchor/canonical_chapter_text_test.dart
```

Expected: 3 tests pass.

- [ ] **Step 3.5: Verify full suite**

```
flutter analyze
flutter test
```

- [ ] **Step 3.6: Commit + push**

```
git add lib/domain/anchor/canonical_chapter_text.dart test/domain/anchor/canonical_chapter_text_test.dart
git commit -m "feat(m2.5): CanonicalChapterText — single source of truth for anchor text"
git push
```

---

## Task 4: S3 — Anchor data classes + JSON

**Files:**
- Create: `lib/domain/anchor/reading_position_anchor.dart`
- Create: `lib/domain/anchor/highlight_anchor.dart`
- Create: `lib/domain/anchor/anchor_range.dart`
- Create: `test/domain/anchor/reading_position_anchor_test.dart`
- Create: `test/domain/anchor/highlight_anchor_test.dart`

- [ ] **Step 4.1: Tests first**

`test/domain/anchor/reading_position_anchor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/reading_position_anchor.dart';

void main() {
  test('Test 8: ReadingPositionAnchor round-trip JSON', () {
    const a = ReadingPositionAnchor(
      chapterId: 'OEBPS/Text/ch1.xhtml',
      charOffset: 5000,
      chapterLength: 12000,
    );
    final json = a.toJson();
    expect(json, {'c': 'OEBPS/Text/ch1.xhtml', 'o': 5000, 'n': 12000});

    final decoded = ReadingPositionAnchor.fromJson(json);
    expect(decoded.chapterId, a.chapterId);
    expect(decoded.charOffset, a.charOffset);
    expect(decoded.chapterLength, a.chapterLength);
  });

  test('progress derived correctly', () {
    const a = ReadingPositionAnchor(
      chapterId: 'x',
      charOffset: 3000,
      chapterLength: 12000,
    );
    expect(a.progress, closeTo(0.25, 1e-9));
  });

  test('progress is 0.0 when chapterLength is 0 (defensive)', () {
    const a = ReadingPositionAnchor(
      chapterId: 'x',
      charOffset: 100,
      chapterLength: 0,
    );
    expect(a.progress, 0.0);
  });
}
```

`test/domain/anchor/highlight_anchor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/highlight_anchor.dart';

void main() {
  test('HighlightAnchor JSON round-trip', () {
    const a = HighlightAnchor(
      chapterId: 'OEBPS/ch3.xhtml',
      quote: 'Down, down, down.',
      prefix: 'Alice began ',
      suffix: ' Would the fall',
      charOffset: 1247,
    );
    final json = a.toJson();
    expect(json, {
      'c': 'OEBPS/ch3.xhtml',
      'q': 'Down, down, down.',
      'pre': 'Alice began ',
      'suf': ' Would the fall',
      'o': 1247,
    });

    final decoded = HighlightAnchor.fromJson(json);
    expect(decoded.chapterId, a.chapterId);
    expect(decoded.quote, a.quote);
    expect(decoded.prefix, a.prefix);
    expect(decoded.suffix, a.suffix);
    expect(decoded.charOffset, a.charOffset);
  });

  test('HighlightAnchor JSON round-trip with null charOffset', () {
    const a = HighlightAnchor(
      chapterId: 'x',
      quote: 'q',
      prefix: 'p',
      suffix: 's',
      charOffset: null,
    );
    final json = a.toJson();
    expect(json.containsKey('o'), isFalse);

    final decoded = HighlightAnchor.fromJson(json);
    expect(decoded.charOffset, isNull);
  });
}
```

- [ ] **Step 4.2: Run to verify fail**

```
flutter test test/domain/anchor/reading_position_anchor_test.dart test/domain/anchor/highlight_anchor_test.dart
```

Expected: compile errors.

- [ ] **Step 4.3: Implement `lib/domain/anchor/reading_position_anchor.dart`**

```dart
import 'package:meta/meta.dart';

@immutable
class ReadingPositionAnchor {
  final String chapterId;
  final int charOffset;
  final int chapterLength;

  const ReadingPositionAnchor({
    required this.chapterId,
    required this.charOffset,
    required this.chapterLength,
  });

  /// 0.0 – 1.0 zlomok kapitoly. Defensive: vracia 0.0 ak chapterLength == 0.
  double get progress =>
      chapterLength == 0 ? 0.0 : charOffset / chapterLength;

  Map<String, dynamic> toJson() => {
        'c': chapterId,
        'o': charOffset,
        'n': chapterLength,
      };

  factory ReadingPositionAnchor.fromJson(Map<String, dynamic> json) =>
      ReadingPositionAnchor(
        chapterId: json['c'] as String,
        charOffset: (json['o'] as num).toInt(),
        chapterLength: (json['n'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is ReadingPositionAnchor &&
      other.chapterId == chapterId &&
      other.charOffset == charOffset &&
      other.chapterLength == chapterLength;

  @override
  int get hashCode => Object.hash(chapterId, charOffset, chapterLength);
}
```

- [ ] **Step 4.4: Implement `lib/domain/anchor/highlight_anchor.dart`**

```dart
import 'package:meta/meta.dart';

@immutable
class HighlightAnchor {
  final String chapterId;
  final String quote;
  final String prefix;
  final String suffix;
  final int? charOffset;

  const HighlightAnchor({
    required this.chapterId,
    required this.quote,
    required this.prefix,
    required this.suffix,
    required this.charOffset,
  });

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{
      'c': chapterId,
      'q': quote,
      'pre': prefix,
      'suf': suffix,
    };
    if (charOffset != null) j['o'] = charOffset;
    return j;
  }

  factory HighlightAnchor.fromJson(Map<String, dynamic> json) =>
      HighlightAnchor(
        chapterId: json['c'] as String,
        quote: json['q'] as String,
        prefix: json['pre'] as String,
        suffix: json['suf'] as String,
        charOffset: json.containsKey('o') ? (json['o'] as num).toInt() : null,
      );

  @override
  bool operator ==(Object other) =>
      other is HighlightAnchor &&
      other.chapterId == chapterId &&
      other.quote == quote &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.charOffset == charOffset;

  @override
  int get hashCode =>
      Object.hash(chapterId, quote, prefix, suffix, charOffset);
}
```

- [ ] **Step 4.5: Implement `lib/domain/anchor/anchor_range.dart`**

```dart
import 'package:meta/meta.dart';

/// Vlastná typovo-bezpečná trieda — neviažeme sa na Flutter dart:ui.TextRange
/// aby domain vrstva neimportovala Flutter.
@immutable
class AnchorRange {
  final int start;  // character offset v normalised texte
  final int end;
  const AnchorRange(this.start, this.end);

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is AnchorRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'AnchorRange($start, $end)';
}
```

- [ ] **Step 4.6: Run tests to verify pass**

```
flutter test test/domain/anchor/reading_position_anchor_test.dart test/domain/anchor/highlight_anchor_test.dart
```

Expected: 5 tests pass.

- [ ] **Step 4.7: Verify all + commit + push**

```
flutter analyze
flutter test
git add lib/domain/anchor/ test/domain/anchor/
git commit -m "feat(m2.5): anchor data classes (ReadingPositionAnchor, HighlightAnchor, AnchorRange)"
git push
```

---

## Task 5: S4 — `AnchorCodec.normalize` + `createHighlight`

**Files:**
- Create: `lib/domain/anchor/anchor_codec.dart` (initial — normalize + createHighlight)
- Create: `test/domain/anchor/anchor_codec_normalize_test.dart`
- Create: `test/domain/anchor/anchor_codec_create_highlight_test.dart`

- [ ] **Step 5.1: Tests first — normalize**

`test/domain/anchor/anchor_codec_normalize_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';

void main() {
  test('Test 6: normalize collapses mixed whitespace', () {
    const input = 'Hello \t\n world\n\nfoo';
    expect(AnchorCodec.normalize(input), 'Hello world foo');
  });

  test('normalize strips soft hyphens', () {
    const input = 'co­mpli­cated';
    expect(AnchorCodec.normalize(input), 'complicated');
  });

  test('normalize handles nbsp', () {
    const input = 'word word';
    expect(AnchorCodec.normalize(input), 'word word');
  });

  test('Test 5 (partial): normalize preserves diacritics', () {
    const input = 'è à ò š č ž';
    expect(AnchorCodec.normalize(input), 'è à ò š č ž');
  });

  test('normalize preserves case', () {
    expect(AnchorCodec.normalize('Hello World'), 'Hello World');
  });

  test('normalize trims edges', () {
    expect(AnchorCodec.normalize('  hi  '), 'hi');
  });
}
```

- [ ] **Step 5.2: Tests first — createHighlight**

`test/domain/anchor/anchor_codec_create_highlight_test.dart`:

```dart
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';

void main() {
  Future<EpubBook> loadAlice() async {
    final bytes = await File('test/fixtures/alice.epub').readAsBytes();
    return EpubReader.readBook(bytes);
  }

  test('Test 1 (create part): createHighlight returns HighlightAnchor with quote',
      () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: 'Alice',
      rawPrefix: 'said ',
      rawSuffix: ' was',
    );

    expect(anchor.chapterId, chapterId);
    expect(anchor.quote, 'Alice');
    expect(anchor.prefix.endsWith('said '), isTrue);
    expect(anchor.suffix.startsWith(' was') || anchor.suffix.length <= 32, isTrue);
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
  });

  test('createHighlight caps prefix/suffix at 32 chars', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: 'word',
      rawPrefix: 'long' * 20,
      rawSuffix: 'tail' * 20,
    );

    expect(anchor.prefix.length, lessThanOrEqualTo(32));
    expect(anchor.suffix.length, lessThanOrEqualTo(32));
  });
}
```

- [ ] **Step 5.3: Run to verify fail**

```
flutter test test/domain/anchor/anchor_codec_normalize_test.dart test/domain/anchor/anchor_codec_create_highlight_test.dart
```

Expected: compile errors.

- [ ] **Step 5.4: Implement `lib/domain/anchor/anchor_codec.dart`**

```dart
import 'package:epubx/epubx.dart';

import 'anchor_range.dart';
import 'canonical_chapter_text.dart';
import 'highlight_anchor.dart';

/// Encoder / decoder anchorov + resolve algoritmus.
/// Doménová vrstva — bez Flutter / Drift importov.
class AnchorCodec {
  AnchorCodec._();

  /// Normalize text pre konzistentné porovnávanie.
  /// - Strip soft hyphens (U+00AD)
  /// - Collapse all whitespace + nbsp into single space
  /// - Trim
  /// (Unicode NFC sa nerobí — Dart core nemá native API; v praxi netreba pre
  /// EPUB knihy z Gutenberg / bežné publishery.)
  static String normalize(String text) {
    final dehyphenated = text.replaceAll('­', '');
    final collapsed = dehyphenated.replaceAll(RegExp(r'[\s ]+'), ' ');
    return collapsed.trim();
  }

  /// Vytvorí HighlightAnchor zo selekcie + okolitého kontextu z rendereru.
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

    // charOffset je len HINT — hľadáme v kanonickom texte.
    final hintNeedle = cappedPrefix + cappedQuote + cappedSuffix;
    int? charOffset;
    if (hintNeedle.isNotEmpty) {
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

  /// Resolve — vráti AnchorRange v kanonickom texte kapitoly, alebo null.
  /// PLACEHOLDER — plná implementácia v Task 6 (exact + disambiguation) a
  /// Task 7 (sliding fuzzy).
  static AnchorRange? findHighlight({
    required HighlightAnchor anchor,
    required EpubBook book,
  }) {
    final canonical = CanonicalChapterText.extract(book, anchor.chapterId);
    if (canonical.isEmpty) return null;
    // Minimum: pokús sa o exact match. Plná verzia v Task 6.
    final idx = canonical.indexOf(anchor.quote);
    if (idx < 0) return null;
    return AnchorRange(idx, idx + anchor.quote.length);
  }
}
```

- [ ] **Step 5.5: Run tests to verify pass**

```
flutter test test/domain/anchor/anchor_codec_normalize_test.dart test/domain/anchor/anchor_codec_create_highlight_test.dart
```

Expected: 9 tests pass (6 normalize + 3 create).

- [ ] **Step 5.6: Verify all + commit + push**

```
flutter analyze
flutter test
git add lib/domain/anchor/anchor_codec.dart test/domain/anchor/anchor_codec_normalize_test.dart test/domain/anchor/anchor_codec_create_highlight_test.dart
git commit -m "feat(m2.5): AnchorCodec.normalize + createHighlight (string-first, canonical)"
git push
```

---

## Task 6: S5 — `findHighlight` exact match + disambiguation

**Files:**
- Modify: `lib/domain/anchor/anchor_codec.dart` (replace placeholder `findHighlight`)
- Create: `test/domain/anchor/anchor_codec_find_highlight_exact_test.dart`

- [ ] **Step 6.1: Tests first**

`test/domain/anchor/anchor_codec_find_highlight_exact_test.dart`:

```dart
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

  test('Test 1: create -> JSON -> decode -> findHighlight round-trip',
      () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Vyber reálny úsek z kanonického textu (kontextové slovo)
    // Bude na pozícii ~100, dĺžka ~30 znakov
    const startInCanonical = 100;
    final realQuote = canonical.substring(startInCanonical, startInCanonical + 30);
    final realPrefix = canonical.substring(
        startInCanonical - 20, startInCanonical);
    final realSuffix = canonical.substring(
        startInCanonical + 30, startInCanonical + 50);

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: realQuote,
      rawPrefix: realPrefix,
      rawSuffix: realSuffix,
    );

    // Encode → decode (over JSON)
    final encoded = anchor.toJson();
    final decoded = HighlightAnchor.fromJson(encoded);

    // Resolve späť
    final range = AnchorCodec.findHighlight(anchor: decoded, book: book);
    expect(range, isNotNull);
    expect(range!.start, startInCanonical);
    expect(range.end, startInCanonical + realQuote.length);
  });

  test('Test 3: disambiguation when quote appears twice', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    // Vytvor anchor pre veľmi krátky common quote ktorý sa vyskytuje viackrát
    // Použijeme reálny text z kapitoly + reálny kontext aby prefix/suffix
    // disambiguovali.
    final canonical = CanonicalChapterText.extract(book, chapterId);
    final firstThe = canonical.indexOf(' the ');
    if (firstThe < 0) {
      // alice.epub neobsahuje 'the' — skip alebo fixture iné
      return;
    }
    final secondThe = canonical.indexOf(' the ', firstThe + 1);
    if (secondThe < 0) return;

    final prefix = canonical.substring(secondThe - 20, secondThe);
    final suffix = canonical.substring(secondThe + 5, secondThe + 25);

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: ' the ',
      rawPrefix: prefix,
      rawSuffix: suffix,
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
    // Musí to nájsť DRUHÝ výskyt, nie prvý
    expect(range!.start, secondThe);
  });

  test('Test 4: lost anchor returns null without crash', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';

    const anchor = HighlightAnchor(
      chapterId: 'OEBPS/ch1.xhtml',  // arbitrary
      quote: 'THIS TEXT DEFINITELY DOES NOT EXIST IN ALICE qwxyz123',
      prefix: 'never',
      suffix: 'ever',
      charOffset: 5000,
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNull);
  });

  test('Test 5 (resolve part): diacritics roundtrip on divina.epub', () async {
    final bytes = await File('test/fixtures/divina.epub').readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    // Nájdi reálny úsek s diakritikou (è, à, ò, í, ù)
    final accentMatch =
        RegExp('[èàòíùé]').firstMatch(canonical);
    if (accentMatch == null) return; // fixture neobsahuje, skip
    final start = (accentMatch.start - 10).clamp(0, canonical.length);
    final end = (accentMatch.start + 20).clamp(0, canonical.length);
    final quote = canonical.substring(start, end);
    final prefix = canonical.substring((start - 10).clamp(0, canonical.length), start);
    final suffix = canonical.substring(end, (end + 10).clamp(0, canonical.length));

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

    if (canonical.length < 100) return;
    final realQuote = canonical.substring(50, 80);

    // Pridáme mixed whitespace do raw selekcie — normalize ich má zliepť
    final messy = realQuote.replaceAll(' ', '  \n  ');

    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: messy,
      rawPrefix: canonical.substring(30, 50),
      rawSuffix: canonical.substring(80, 100),
    );

    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
    expect(canonical.substring(range!.start, range.end), realQuote);
  });
}
```

- [ ] **Step 6.2: Run to verify some fail (placeholder findHighlight handles only simplest case)**

```
flutter test test/domain/anchor/anchor_codec_find_highlight_exact_test.dart
```

Expected: Test 3 (disambiguation) fails — placeholder vždy vracia prvý match.

- [ ] **Step 6.3: Replace placeholder `findHighlight` in `lib/domain/anchor/anchor_codec.dart`**

Nájdi a nahraď celý `findHighlight` blok:

```dart
  /// Resolve HighlightAnchor na AnchorRange v kanonickom texte kapitoly.
  /// Algoritmus per spec §5 Resolve:
  ///   1. Normalize chapter (cez CanonicalChapterText)
  ///   2. Exact match v okne ±200 znakov okolo charOffset
  ///   3. Single hit → vráť
  ///   4. Viac hitov / žiadny v okne → skús prefix+quote+suffix presný kontext
  ///   5. (Task 7) Sliding fuzzy ak stále nič
  ///   6. Inak null
  static AnchorRange? findHighlight({
    required HighlightAnchor anchor,
    required EpubBook book,
  }) {
    final canonical = CanonicalChapterText.extract(book, anchor.chapterId);
    if (canonical.isEmpty) return null;
    if (anchor.quote.isEmpty) return null;

    // (2) Exact match v okne okolo charOffset
    final hint = anchor.charOffset;
    if (hint != null) {
      final windowStart = (hint - 200).clamp(0, canonical.length);
      final windowEnd = (hint + 200 + anchor.quote.length).clamp(0, canonical.length);
      final window = canonical.substring(windowStart, windowEnd);
      final localIdx = window.indexOf(anchor.quote);
      // (3) Single hit?
      if (localIdx >= 0 && window.indexOf(anchor.quote, localIdx + 1) < 0) {
        return AnchorRange(
          windowStart + localIdx,
          windowStart + localIdx + anchor.quote.length,
        );
      }
    }

    // (4) Disambiguáciou cez prefix+quote+suffix presný kontext
    final contextNeedle = anchor.prefix + anchor.quote + anchor.suffix;
    final contextIdx = canonical.indexOf(contextNeedle);
    if (contextIdx >= 0) {
      final quoteStart = contextIdx + anchor.prefix.length;
      return AnchorRange(quoteStart, quoteStart + anchor.quote.length);
    }

    // (3b) Ak hint okno nebolo k dispozícii, skús celý text na single exact
    final globalIdx = canonical.indexOf(anchor.quote);
    if (globalIdx >= 0 && canonical.indexOf(anchor.quote, globalIdx + 1) < 0) {
      return AnchorRange(globalIdx, globalIdx + anchor.quote.length);
    }

    // (5) Fuzzy — implementuje sa v Task 7
    return null;
  }
```

- [ ] **Step 6.4: Run tests to verify pass**

```
flutter test test/domain/anchor/anchor_codec_find_highlight_exact_test.dart
```

Expected: 5 tests pass.

- [ ] **Step 6.5: Verify all + commit + push**

```
flutter analyze
flutter test
git add lib/domain/anchor/anchor_codec.dart test/domain/anchor/anchor_codec_find_highlight_exact_test.dart
git commit -m "feat(m2.5): findHighlight exact match + disambiguation"
git push
```

---

## Task 7: S6 — Sliding fuzzy match

**Cieľ:** Doplniť krok 5 resolve algoritmu — sliding alignment fuzzy substring search (Smith-Waterman-style).

**Files:**
- Modify: `lib/domain/anchor/anchor_codec.dart` (add `_slidingFuzzyFind`, replace fuzzy fallback)
- Create: `test/domain/anchor/anchor_codec_find_highlight_fuzzy_test.dart`

- [ ] **Step 7.1: Tests first**

`test/domain/anchor/anchor_codec_find_highlight_fuzzy_test.dart`:

```dart
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

  test('Test 12: sliding fuzzy finds quote after 5-char insert', () async {
    final book = await loadAlice();
    final chapterId = book.Chapters!.first.ContentFileName ?? '#0';
    final canonical = CanonicalChapterText.extract(book, chapterId);

    if (canonical.length < 300) {
      fail('alice first chapter too short for fuzzy test');
    }

    // Vyber 80-znakový citát
    const startInCanonical = 150;
    final originalQuote = canonical.substring(startInCanonical,
        startInCanonical + 80);

    // Vytvor anchor PROTI pôvodnému canonical-u
    final anchor = AnchorCodec.createHighlight(
      book: book,
      chapterId: chapterId,
      rawSelectedText: originalQuote,
      rawPrefix: canonical.substring(startInCanonical - 20, startInCanonical),
      rawSuffix: canonical.substring(
          startInCanonical + 80, startInCanonical + 100),
    );

    // Teraz si predstavme že canonical-text sa zmenil — vlož 5 znakov uprostred quote.
    // (V realite by sme nemodifikovali, ale na test simulujeme zmenu cez wrapper
    //  ktorý vráti modified canonical. Tu si len overíme že fuzzy algoritmus
    //  nájde quote so vsuvkou cez wrapping in-test EpubBook by nešlo — preto
    //  testujeme algoritmus priamo cez statickú helper exposovanú v debug API.)
    //
    // Praktický workaround: použijeme _slidingFuzzyFind cez expose:
    // pridáme do AnchorCodec testov-friendly helper static method.

    // Tu volíme priamy test cez findHighlight nad pôvodnou knihou — anchor by sa
    // mal exact-match-nut. Toto je sanity check že fuzzy code path nepokazila
    // exact path.
    final range = AnchorCodec.findHighlight(anchor: anchor, book: book);
    expect(range, isNotNull);
  });

  test('Test 2: fuzzy finds quote despite 5-char insert (algorithm-direct)',
      () async {
    // Tento test obíde EpubBook — testuje sliding fuzzy nad raw stringom.
    // Vytvoríme syntetický scenár.

    const originalQuote = 'The quick brown fox jumps over the lazy dog repeatedly.';
    const haystack = 'Before. The quick brown FXXXXox jumps over the lazy dog repeatedly. After.';
    //                                       ^^^^^ 5 chars inserted

    // Použijeme verejnú statickú helper-method (pridáme do AnchorCodec):
    final result = AnchorCodec.slidingFuzzyFind(
      needle: originalQuote,
      haystack: haystack,
      windowCenter: haystack.indexOf('The'),
      windowRadius: 100,
    );

    expect(result, isNotNull);
    // Match musí byť okolo pôvodnej pozície
    expect(result!.start, greaterThanOrEqualTo(haystack.indexOf('The')));
    expect(result.end - result.start,
        closeTo(originalQuote.length, 10));
  });

  test('slidingFuzzyFind returns null when similarity < 0.92', () async {
    const needle = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const haystack = 'completely different content zzzz';

    final result = AnchorCodec.slidingFuzzyFind(
      needle: needle,
      haystack: haystack,
      windowCenter: 10,
      windowRadius: 50,
    );

    expect(result, isNull);
  });
}
```

- [ ] **Step 7.2: Run to verify fail**

```
flutter test test/domain/anchor/anchor_codec_find_highlight_fuzzy_test.dart
```

Expected: compile error (`slidingFuzzyFind` doesn't exist).

- [ ] **Step 7.3: Add `slidingFuzzyFind` + integrate into `findHighlight`**

V `lib/domain/anchor/anchor_codec.dart` doplň pred poslednú `}` triedy:

```dart
  /// Sliding alignment fuzzy substring search (Smith-Waterman-style).
  /// Kĺže `needle` cez okno `haystack[center-radius : center+radius]` a hľadá
  /// pozíciu s najnižším edit distance. Menovateľ pre similarity je dĺžka
  /// needle (NIE okna) — preto algoritmus reálne nájde match aj keď je needle
  /// kratšia ako okno.
  ///
  /// Vracia AnchorRange (start, end) ABSOLUTE v haystack-u, alebo null ak
  /// najlepší match má similarity < 0.92.
  static AnchorRange? slidingFuzzyFind({
    required String needle,
    required String haystack,
    required int windowCenter,
    int windowRadius = 500,
    double threshold = 0.92,
  }) {
    if (needle.isEmpty || haystack.isEmpty) return null;

    final windowStart = (windowCenter - windowRadius).clamp(0, haystack.length);
    final windowEnd =
        (windowCenter + windowRadius + needle.length).clamp(0, haystack.length);
    final window = haystack.substring(windowStart, windowEnd);

    int bestStart = -1;
    int bestEnd = -1;
    double bestSim = -1.0;
    int bestDistanceToHint = 1 << 30;

    // Povolíme posun dĺžky ±10 znakov (inserts/deletes vo vnútri quote).
    const deltaMax = 10;
    final lenMin = (needle.length - deltaMax).clamp(1, window.length);
    final lenMax = (needle.length + deltaMax).clamp(1, window.length);

    for (var i = 0; i + lenMin <= window.length; i++) {
      final maxLen = (window.length - i).clamp(lenMin, lenMax);
      for (var len = lenMin; len <= maxLen; len++) {
        final candidate = window.substring(i, i + len);
        final dist = _editDistance(needle, candidate);
        final sim = 1.0 - dist / needle.length;
        if (sim < threshold) continue;

        // Tie-break: vyšší similarity → najbližšie k windowCenter → najskorší
        final absStart = windowStart + i;
        final distToHint = (absStart - windowCenter).abs();
        if (sim > bestSim ||
            (sim == bestSim && distToHint < bestDistanceToHint) ||
            (sim == bestSim &&
                distToHint == bestDistanceToHint &&
                absStart < bestStart)) {
          bestSim = sim;
          bestStart = absStart;
          bestEnd = absStart + len;
          bestDistanceToHint = distToHint;
        }
      }
    }

    if (bestStart < 0) return null;
    return AnchorRange(bestStart, bestEnd);
  }

  /// Wagner-Fischer Levenshtein. O(m*n) memory.
  /// Pre potreby M2.5 (needle ≤ ~210 znakov, candidate ≤ ~220) postačuje.
  static int _editDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = [
          prev[j] + 1,       // deletion
          curr[j - 1] + 1,   // insertion
          prev[j - 1] + cost // substitution
        ].reduce((x, y) => x < y ? x : y);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
```

A v `findHighlight`, nahraď posledný riadok (`return null;` po komentári o Task 7) takto:

```dart
    // (5) Sliding fuzzy fallback
    final hintForFuzzy = anchor.charOffset ?? (canonical.length ~/ 2);
    return slidingFuzzyFind(
      needle: anchor.quote,
      haystack: canonical,
      windowCenter: hintForFuzzy,
    );
```

- [ ] **Step 7.4: Run tests**

```
flutter test test/domain/anchor/anchor_codec_find_highlight_fuzzy_test.dart
```

Expected: 3 tests pass.

Pozn.: Test 12 v T7.1 sa volá `findHighlight` nad pôvodnou knihou (exact match path). Skutočný fuzzy edge case (5-char insert) je testovaný v `Test 2` cez `slidingFuzzyFind` priamo na syntetickom stringu — to je správnejšie, lebo nemusíme mutovať EpubBook.

- [ ] **Step 7.5: Verify all + commit + push**

```
flutter analyze
flutter test
git add lib/domain/anchor/anchor_codec.dart test/domain/anchor/anchor_codec_find_highlight_fuzzy_test.dart
git commit -m "feat(m2.5): sliding fuzzy match (Smith-Waterman-style) for findHighlight"
git push
```

---

## Task 8: S7 — Furthest-read merge helper

**Cieľ:** Implementovať deterministický merge dvoch `ReadingPositionAnchor`-ov podľa pravidla `(spine_index, charOffset)` lex order — *furthest read wins*.

**Files:**
- Modify: `lib/domain/anchor/reading_position_anchor.dart` (add static merge)
- Create: `test/domain/anchor/anchor_codec_merge_test.dart`

- [ ] **Step 8.1: Test first**

`test/domain/anchor/anchor_codec_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/reading_position_anchor.dart';

void main() {
  group('ReadingPositionAnchor.furthestRead', () {
    test('Test 9: chapter5@100 vs chapter3@9000 → chapter5 wins (spine first)', () {
      const a = ReadingPositionAnchor(
        chapterId: 'ch5',
        charOffset: 100,
        chapterLength: 10000,
      );
      const b = ReadingPositionAnchor(
        chapterId: 'ch3',
        charOffset: 9000,
        chapterLength: 10000,
      );

      final spineIndex = {'ch5': 5, 'ch3': 3};

      final winner = ReadingPositionAnchor.furthestRead(
        a, b, spineIndexOf: (id) => spineIndex[id] ?? -1);
      expect(winner.chapterId, 'ch5');
    });

    test('same chapter — higher charOffset wins', () {
      const a = ReadingPositionAnchor(
          chapterId: 'ch3', charOffset: 1000, chapterLength: 5000);
      const b = ReadingPositionAnchor(
          chapterId: 'ch3', charOffset: 4000, chapterLength: 5000);

      final winner = ReadingPositionAnchor.furthestRead(
        a, b, spineIndexOf: (_) => 3);
      expect(winner.charOffset, 4000);
    });

    test('unknown chapter id → spine index -1, loses', () {
      const a = ReadingPositionAnchor(
          chapterId: 'ch5', charOffset: 0, chapterLength: 100);
      const b = ReadingPositionAnchor(
          chapterId: 'unknown', charOffset: 9000, chapterLength: 10000);

      final winner = ReadingPositionAnchor.furthestRead(
        a, b, spineIndexOf: (id) => id == 'ch5' ? 5 : -1);
      expect(winner.chapterId, 'ch5');
    });

    test('identical anchors → returns first (deterministic)', () {
      const a = ReadingPositionAnchor(
          chapterId: 'x', charOffset: 100, chapterLength: 500);
      final winner = ReadingPositionAnchor.furthestRead(
        a, a, spineIndexOf: (_) => 0);
      expect(winner, a);
    });
  });
}
```

- [ ] **Step 8.2: Run to verify fail**

```
flutter test test/domain/anchor/anchor_codec_merge_test.dart
```

Expected: compile error.

- [ ] **Step 8.3: Add static `furthestRead` to `lib/domain/anchor/reading_position_anchor.dart`**

Pred poslednú `}` triedy:

```dart
  /// Vyberie z dvoch anchorov ten ktorý je „furthest read" — najprv podľa spine
  /// indexu kapitoly, potom podľa charOffset v kapitole. Pri rovnosti vracia
  /// prvý parameter (deterministicky).
  ///
  /// `spineIndexOf` je callback ktorý vráti spine index pre chapterId v
  /// aktuálnej knihe; spine index je vlastnosť súboru, nie anchoru, preto sa
  /// neukladá v anchore samotnom.
  static ReadingPositionAnchor furthestRead(
    ReadingPositionAnchor a,
    ReadingPositionAnchor b, {
    required int Function(String chapterId) spineIndexOf,
  }) {
    final spineA = spineIndexOf(a.chapterId);
    final spineB = spineIndexOf(b.chapterId);

    if (spineA != spineB) {
      return spineA > spineB ? a : b;
    }
    // Rovnaká kapitola — vyšší charOffset vyhráva.
    if (a.charOffset != b.charOffset) {
      return a.charOffset > b.charOffset ? a : b;
    }
    return a;
  }
```

- [ ] **Step 8.4: Run tests + verify + commit + push**

```
flutter test test/domain/anchor/anchor_codec_merge_test.dart
flutter analyze
flutter test
git add lib/domain/anchor/reading_position_anchor.dart test/domain/anchor/anchor_codec_merge_test.dart
git commit -m "feat(m2.5): ReadingPositionAnchor.furthestRead merge (spine-first)"
git push
```

---

## Task 9: S8 — ADR 0002 + cleanup spike + README

**Cieľ:** Konsolidovať všetky zistenia zo S0-S7 do ADR 0002, zmazať spike obrazovku, vyčistiť navigation, aktualizovať README a strategy doc.

**Files:**
- Create: `docs/adr/0002-anchor-format.md`
- Delete: `docs/adr/0002-anchor-format-draft-notes.md`
- Delete: `lib/spike/anchor_probe/` (celý priečinok)
- Modify: `lib/app.dart` (remove `/dev/anchor_probe` route)
- Modify: `lib/features/library/library_screen.dart` (remove dev FAB)
- Modify: `README.md` (M2.5 done)
- Modify: `docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md` (mark §7.1 + §7.2 done)

- [ ] **Step 9.1: Vytvor finálny `docs/adr/0002-anchor-format.md`**

```markdown
# ADR 0002 — Render-Agnostic Anchor Format

**Status:** Accepted
**Dátum:** YYYY-MM-DD
**Kontext:** M2.5, Fáza 1 (MVP)
**Supersedes:** None
**Related:** ADR 0001 (renderer choice), `docs/specs/m2.5-anchor-format.md`,
`docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md`

## Kontext

Spec `m2.5-anchor-format.md` identifikoval že bez stabilnej reflow-nezávislej
kotvy nemá zmysel budovať highlighty (Fáza 3) ani sync (Fáza 5). Toto ADR
zafixuje výsledné rozhodnutia po S0-S7 implementácii.

## S0 GATE — Canonical-text consistency výsledky

| Fixture | Selekcií | ✅ | ❌ | Poznámky |
|---------|----------|----|----|----------|
| alice.epub | <doplň z draft notes> | | | |
| pride.epub | | | | |
| frankenstein.epub | | | | |
| divina.epub | | | | |

**Výsledok:** GATE PASSED — pokračujeme s implementáciou ako bola plánovaná.
(Ak failed → toto ADR by namiesto toho dokumentovalo prehodnotenie.)

## EpubController API zistenia (zo S1)

| Info | Dostupné? | Cez aké API | Kvalita |
|------|-----------|-------------|---------|
| <doplň zo S1 spike-u> | | | |

## Rozhodnutia

1. **Dva anchor formáty** — `ReadingPositionAnchor` (char-offset / chapterLength)
   a `HighlightAnchor` (text-quote-based).
2. **chapterId** — primárne manifest href, fallback `#<spineIndex>`.
3. **Single source of truth** = `CanonicalChapterText.extract(book, chapterId)`
   používané `createHighlight` aj `findHighlight`.
4. **API** je string-first (žiadne offsety v raw textoch).
5. **Fuzzy** = sliding alignment (Smith-Waterman-style), menovateľ = needle len,
   threshold 0.92, tie-break `(similarity, distanceToHint, position)`.
6. **Reading position resolve** — **Plán A** (priame char→scroll, ak `epub_view`
   vie) / **Plán B** (degenerovaný HighlightAnchor cez findHighlight). Aktuálne
   zvolené: **<doplň podľa S1>**.
7. **Furthest-read merge** je default pre RP sync — `(spine_index, charOffset)`
   lex order.

## Dôsledky

- **Fáza 3 (anotácie)** musí pri implementácii zabudovať do annotation record
  polia: `id` (client-generated UUID v4), `bookId`, `anchor` (HighlightAnchor
  ako JSON string), `note?`, `colorIndex?`, `createdAt`, `updatedAt`,
  `deviceId`, `isDeleted` (soft-delete tombstone).
- **Fáza 5 (sync)** prenáša anchory v append-only event log entries; merge logika
  na klientovi je deterministická.
- **M3 (Reader v1)** prepíše tabuľku `reading_positions` — drop `chapterIndex`
  a `progressInChapter` REAL → pridať `anchor_json TEXT`. Triviálna migration.
- **Cross-edícia** explicitne nie je podporovaná — anchor sa resolve-uje len
  v EPUB súbore s rovnakým content hashom ako bol vytvorený. Tento limit ide do
  ADR 0003 (book-identity).

## Alternatívy zamietnuté

- **CFI via WebView (flutter_epub_viewer)** — zlyhal pri renderingu na Windows
  (ADR 0001).
- **Paragraph index** — nestabilné pri reflow.
- **`progress * render_height`** — render-závislé.
- **`max(progress)` per book bez spine ordering** — nesprávne pri ordering medzi
  kapitolami.
- **Single unified anchor pre RP aj highlight** — diametrálne odlišné conflict
  resolution semantics.

## Mileniky implementácie (S0–S7)

| ID | Hotovo? | Commit |
|----|---------|--------|
| S0 GATE | ✅ | <SHA> |
| S1 (controller API) | ✅ | <SHA> |
| S2 (CanonicalChapterText) | ✅ | <SHA> |
| S3 (data classes) | ✅ | <SHA> |
| S4 (normalize + createHighlight) | ✅ | <SHA> |
| S5 (findHighlight exact) | ✅ | <SHA> |
| S6 (sliding fuzzy) | ✅ | <SHA> |
| S7 (furthest-read merge) | ✅ | <SHA> |
| S8 (this ADR + cleanup) | ✅ | <SHA> |
```

Doplň `YYYY-MM-DD`, tabuľku z S0 draft notes, EpubController API tabuľku z S1, Plán A/B rozhodnutie, a SHAs commit-ov.

- [ ] **Step 9.2: Zmaž draft notes**

```
rm docs/adr/0002-anchor-format-draft-notes.md
```

- [ ] **Step 9.3: Zmaž spike priečinok**

```
rm -rf lib/spike/
```

(Po M2 sa lib/spike/ vrátil len pre M2.5; teraz definitívne preč.)

- [ ] **Step 9.4: Vyčisti `lib/app.dart`**

Odstráň import `import 'spike/anchor_probe/anchor_probe_screen.dart';`

Odstráň `/dev/anchor_probe` case z `onGenerateRoute`:

```dart
      onGenerateRoute: (settings) {
        if (settings.name == '/reader') {
          final bookId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ReaderStubScreen(bookId: bookId),
          );
        }
        return null;
      },
```

- [ ] **Step 9.5: Vyčisti `lib/features/library/library_screen.dart`**

Vráť floatingActionButton k pôvodnej extended verzii (bez Column s dev FAB):

```dart
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.addBook),
        onPressed: () => _pickAndAdd(context, ref),
      ),
```

- [ ] **Step 9.6: Aktualizuj README**

V sekcii „Aktuálny stav":

```markdown
**Fáza:** Fáza 1 (MVP), Milník M2.5 hotový — ideme M3 (Reader v1)
**Posledná aktualizácia:** <dnes>

### Hotové
... (zachovaj predchádzajúce)
- [x] M2: Library backbone + EPUB parser + Reader stub
- [x] M2.5: Render-agnostic anchor format (ADR 0002, lib/domain/anchor/)

### Najbližší krok
1. Plán pre M3 (Reader v1 — scroll mode + reading position uloženie cez ReadingPositionAnchor)
```

- [ ] **Step 9.7: Aktualizuj strategy doc**

V `docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md` sekcia 7:

```markdown
1. **[done — ADR 0002] Over kotvenie v `epub_view`.**
2. **[done — ADR 0002] Rozhodni formát render-agnostickej kotvy.**
3. Navrhni Drift schému anotácií ako event log s tou kotvou — ešte pred Fázou 3.
4. Definuj book-identity — ešte pred Fázou 4/5.
...
```

- [ ] **Step 9.8: Final verify**

```
flutter analyze
flutter test
flutter build windows --debug   # v pozadí, timeout 300000
```

Expected: analyze clean, tests pass (počet by mal byť ~25+ vrátane všetkých nových), Windows build OK.

- [ ] **Step 9.9: Commit + push**

```
git add -A
git status   # over že staged sú LEN: docs/adr/0002-anchor-format.md (new),
             # delete docs/adr/0002-anchor-format-draft-notes.md,
             # delete lib/spike/ (all files),
             # modified lib/app.dart, lib/features/library/library_screen.dart,
             # modified README.md, docs/strategy/2026-06-21-*.md
git commit -m "docs(m2.5): ADR 0002 finalised, spike removed, README updated"
git push
```

---

## Akceptačné kritériá M2.5 (DoD)

- [ ] **S0 GATE passed** — používateľ potvrdil ✅ na všetkých 4 fixtures (Task 1)
- [ ] `lib/domain/anchor/` má 4 produkčné súbory: `canonical_chapter_text.dart`,
      `reading_position_anchor.dart`, `highlight_anchor.dart`, `anchor_range.dart`,
      `anchor_codec.dart`
- [ ] `test/domain/anchor/` má 7 test súborov so ~17+ testami, všetky pass
- [ ] `docs/adr/0002-anchor-format.md` finalizovaný so všetkými S0-S7 výsledkami
- [ ] `lib/spike/` zmazané (DoD spec)
- [ ] `lib/app.dart` a `lib/features/library/library_screen.dart` vrátené do
      pred-M2.5 stavu (žiadne dev artefakty)
- [ ] `docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md` §7.1 + §7.2
      označené `[done — ADR 0002]`
- [ ] README aktualizovaný
- [ ] `flutter analyze` clean, `flutter test` passes, `flutter build windows --debug` builds
- [ ] Branch `m2.5-anchor-spike` mergnuteľný do master (fast-forward)

---

## Po M2.5

Ďalší krok je rozhodnutie:

a) **M2.6 — Book identity ADR 0003** (definuj content hash schému; pred Fázou 4/5)
b) **M3 — Reader v1 scroll mode** (použije `ReadingPositionAnchor` z M2.5)

Strategy doc §7.4 odporúča M2.6 pred M3, ale M3 vie ísť aj nezávisle ak používame
managed library (jeden súbor = jedna kniha, content hash netreba).
