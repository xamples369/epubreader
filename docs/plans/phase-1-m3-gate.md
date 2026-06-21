# Phase 1 — M3 GATE (Task 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or (recommended for this plan) `superpowers:executing-plans` — inline execution preferred because spike work requires manual UI interaction + judgment calls between steps. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rozhodnúť M3 GATE (M3 spec §5) cez throwaway spike s dvomi probe-mi a trojvetvovým rozhodovacím stromom — výstupom je ADR 0005 ktorý fixuje implementačnú cestu pre zvyšok M3 (T2-T11), alebo escalate na strategický review (Vetva 3 = renderer wall).

**Architecture:** Throwaway spike v `lib/spike/reader_position/` ktorý vystaví `EpubView` na alice.epub a inštrumentuje (1) všetky public API cesty k textu odseku N (Probe 1), (2) ak Probe 1 padne, paragraph count alignment medzi epub_view scrolled paragraphNumber a vlastnou flutter_html-style segmentáciou (Probe 2), (3) `scrollTo(index)` timing check (bonus). Žiadny resolver, žiadne DB integrácie, žiadne UI polish — len merania pre ADR.

**Tech Stack:** Flutter, `epub_view ^3.2.0`, `file_picker`, `html` (z M2.6). Žiadne nové dependencies.

**Scope rozsah:** Iba T1 z M3 spec-u (`docs/specs/m3-reader-v1.md`). T2-T11 dostanú samostatný plán až keď T1 vráti vetvu rozhodnutia.

---

## Predpoklady

- Master má M2.6 (anchor + book identity + tests).
- Branch `m3-reader-v1` aktívny (vznikol pri spec-e).
- Spec `docs/specs/m3-reader-v1.md` schválený.
- `flutter analyze` clean, `flutter test` pass na current master state.

---

## Súborová mapa (po T1)

```
lib/spike/reader_position/                      (THROWAWAY — Task 6 maže)
├── reader_position_probe_screen.dart           (CREATE T2)
└── paragraph_segmenter.dart                    (CREATE T4 — len ak Probe 1 ❌)

lib/app.dart                                    (MODIFY T3 + T6 — add/remove dev route)
lib/features/library/library_screen.dart        (MODIFY T3 + T6 — add/remove dev FAB)

docs/adr/
└── 0005-reader-position-resolve.md             (CREATE T6)

docs/adr/
└── 0005-reader-position-resolve-draft-notes.md (CREATE T1, GROW T2-T5, CONSOLIDATE T6 → ADR final)
```

---

## Task 1: epub_view API surface inventory (statická analýza)

**Cieľ:** Pred stavbou spike-u si zoznámiť aké public API cesty `EpubController` poskytuje pre prístup k textu odseku. Toto je dôkaz pre ADR 0005 — *„skúšali sme nasledujúce metódy"*.

**Files:**
- Create: `docs/adr/0005-reader-position-resolve-draft-notes.md`

- [ ] **Step 1.1: Read epub_view public API**

Otvor `C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/epub_controller.dart` (už máme prečítané z M2.5 S1) a `lib/src/ui/epub_view.dart`.

Vypíš všetky public gettery / metódy na `EpubController` ktoré vracajú niečo paragraph-related alebo text-related.

- [ ] **Step 1.2: Read EpubChapterViewValue, EpubChapter, Paragraph models**

```
C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/data/models/chapter_view_value.dart
C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/data/models/chapter.dart
C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/data/models/paragraph.dart
```

Zaujímajú nás polia ktoré obsahujú text alebo umožňujú index → text mapovanie.

- [ ] **Step 1.3: Skontroluj epub_parser pre paragraph štruktúru**

```
C:/Users/lubos/AppData/Local/Pub/Cache/hosted/pub.dev/epub_view-3.2.0/lib/src/data/epub_parser.dart
```

`epub_view` interne parsuje text na paragraphs — over ako (preserves boundaries? splits on what?).

- [ ] **Step 1.4: Vytvor `docs/adr/0005-reader-position-resolve-draft-notes.md`**

```markdown
# ADR 0005 draft notes

> Pracovný dokument pre M3 GATE. Po T6 sa konsoliduje do
> `docs/adr/0005-reader-position-resolve.md` a tento súbor sa zmaže.

## Probe 1 — kandidátne API cesty k textu odseku N

### Z statickej analýzy `epub_view ^3.2.0` (Task 1):

Kandidát A: `<doplň konkrétny getter/metóda — napr. controller.currentValue?.chapter?.HtmlContent>`
  - Vstup: aktuálne otvorená kapitola
  - Výstup: raw HTML stringu kapitoly (nie odseku N špecificky)
  - Komentár: vyžaduje vlastné rozsekanie HTML → otázka či segmentácia sedí s epub_view

Kandidát B: `<doplň ďalšiu metódu ak existuje>`
  - ...

Kandidát C: ...

## Probe 1 výsledky (po T3)
_(vyplní T3 — performance probe na alice.epub)_

## Probe 2 výsledky (po T4 ak relevantné)
_(vyplní T4 ak Probe 1 padol)_

## scrollTo timing výsledky (po T5)
_(bonus, vyplní T5)_

## Branch decision (T6)
_(Vetva 1 / 2 / 3 + konkrétna API metóda použitá → ADR final)_
```

Vyplň sekciu „Probe 1 — kandidátne API cesty" konkrétnymi findings z Steps 1.1-1.3.

- [ ] **Step 1.5: Commit + push**

```
git add docs/adr/0005-reader-position-resolve-draft-notes.md
git commit -m "docs(m3): GATE draft notes — epub_view API surface inventory"
git push
```

**No `Co-Authored-By:` trailer.** Push immediately.

---

## Task 2: Spike screen — Probe 1 instrumentation

**Cieľ:** Postaviť obrazovku ktorá pre každú kandidátnu API metódu z Task 1 vykoná pokus o získanie textu odseku N a vyhodnotí výsledok (success/failure + dôkaz).

**Files:**
- Create: `lib/spike/reader_position/reader_position_probe_screen.dart`

- [ ] **Step 2.1: Vytvor `lib/spike/reader_position/reader_position_probe_screen.dart`**

```dart
import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Reader Position Probe (M3 GATE T1).
/// Po dokončení M3 sa celý priečinok lib/spike/reader_position/ zmaže.
class ReaderPositionProbeScreen extends StatefulWidget {
  const ReaderPositionProbeScreen({super.key});

  @override
  State<ReaderPositionProbeScreen> createState() =>
      _ReaderPositionProbeScreenState();
}

class _ReaderPositionProbeScreenState
    extends State<ReaderPositionProbeScreen> {
  EpubController? _controller;
  String? _fixtureName;
  String? _error;
  final List<String> _probeLog = [];

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller = null;
      _probeLog.clear();
    });
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      dialogTitle: 'Vyber EPUB fixture',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() {
        _controller = controller;
        _fixtureName = path.split(Platform.pathSeparator).last;
      });

      // Wait for load
      controller.loadingState.addListener(() {
        if (controller.loadingState.value == EpubViewLoadingState.success) {
          _logLine('[load] loadingState = success');
        } else if (controller.loadingState.value ==
            EpubViewLoadingState.error) {
          _logLine('[load] loadingState = ERROR');
        }
      });

      controller.currentValueListenable.addListener(() {
        final v = controller.currentValue;
        _logLine('[scroll] chapter=${v?.chapterNumber} '
            'paragraph=${v?.paragraphNumber} '
            'progress=${v?.progress?.toStringAsFixed(1)}');
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _logLine(String line) {
    setState(() {
      _probeLog.add(line);
      if (_probeLog.length > 100) {
        _probeLog.removeRange(0, _probeLog.length - 100);
      }
    });
  }

  void _runProbe1() {
    final c = _controller;
    if (c == null) {
      _logLine('[probe1] no controller — load fixture first');
      return;
    }
    _logLine('=== PROBE 1: paragraph text via API ===');

    // Kandidát A: currentValue.chapter.HtmlContent
    final cv = c.currentValue;
    if (cv == null) {
      _logLine('[probe1.A] currentValue is null — scroll first to seed');
    } else {
      _logLine('[probe1.A] currentValue.chapter.Title = '
          '"${cv.chapter?.Title}"');
      final html = cv.chapter?.HtmlContent;
      _logLine('[probe1.A] currentValue.chapter.HtmlContent: '
          '${html == null ? "null" : "${html.length} chars (raw HTML — '
              'nie text odseku N priamo)"}');
      _logLine('[probe1.A] currentValue.paragraphNumber = '
          '${cv.paragraphNumber}');
    }

    // Kandidát B: tableOfContents()
    try {
      final toc = c.tableOfContents();
      _logLine('[probe1.B] tableOfContents() returned ${toc.length} entries');
      if (toc.isNotEmpty) {
        _logLine('[probe1.B] sample entry: title="${toc.first.title}" '
            'startIndex=${toc.first.startIndex}');
      }
    } catch (e) {
      _logLine('[probe1.B] tableOfContents() threw: $e');
    }

    // Kandidát C: generateEpubCfi (M2.5 S1 bonus)
    try {
      final cfi = c.generateEpubCfi();
      _logLine('[probe1.C] generateEpubCfi() = '
          '${cfi == null ? "null" : "\"$cfi\""}');
    } catch (e) {
      _logLine('[probe1.C] generateEpubCfi() threw: $e');
    }

    // Kandidát D: gotoEpubCfi roundtrip
    _logLine('[probe1.D] gotoEpubCfi: skip — needs running CFI from C');

    _logLine('=== PROBE 1 END — skopíruj log a vlož do draft notes ===');
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
        title: const Text('Reader Position Probe (M3 GATE)'),
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
          if (_fixtureName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text('Fixture: $_fixtureName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Text('Error: $_error'),
            ),
          Container(
            height: 200,
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _probeLog.join('\n'),
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11),
              ),
            ),
          ),
          if (_controller != null)
            Expanded(child: EpubView(controller: _controller!))
          else
            const Expanded(
              child: Center(child: Text('Klikni priečinok a vyber EPUB')),
            ),
        ],
      ),
      floatingActionButton: _controller == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.science),
              label: const Text('Run Probe 1'),
              onPressed: _runProbe1,
            ),
    );
  }
}
```

- [ ] **Step 2.2: Verify analyze**

Run:
```
flutter analyze lib/spike/reader_position/
```

Expected: `No issues found!`

- [ ] **Step 2.3: Commit + push**

```
git add lib/spike/reader_position/
git commit -m "feat(m3-gate): spike screen with Probe 1 API instrumentation"
git push
```

---

## Task 3: Wire dev route + run Probe 1 manually

**Cieľ:** Sprístupniť spike z Library obrazovky a vykonať Probe 1 na alice.epub. Výsledok zaznamenať do draft notes.

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/features/library/library_screen.dart`
- Modify: `docs/adr/0005-reader-position-resolve-draft-notes.md`

- [ ] **Step 3.1: Pridať route do `lib/app.dart`**

V `onGenerateRoute` callbacku, pred existujúce `/reader` case pridaj:

```dart
        if (settings.name == '/dev/reader_position_probe') {
          return MaterialPageRoute(
            builder: (_) => const ReaderPositionProbeScreen(),
          );
        }
```

A pridaj import navrch:

```dart
import 'spike/reader_position/reader_position_probe_screen.dart';
```

- [ ] **Step 3.2: Pridať dev FAB do `lib/features/library/library_screen.dart`**

Nájdi:
```dart
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.addBook),
        onPressed: () => _pickAndAdd(context, ref),
      ),
```

Nahraď (rovnaký pattern ako M2.5 S0 GATE):
```dart
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'devReaderPositionProbe',
            tooltip: 'DEV: reader position probe (M3 GATE)',
            child: const Icon(Icons.science),
            onPressed: () => Navigator.of(context)
                .pushNamed('/dev/reader_position_probe'),
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

- [ ] **Step 3.3: Verify + commit**

```
flutter analyze
git add lib/app.dart lib/features/library/library_screen.dart
git commit -m "feat(m3-gate): dev route + FAB for reader position probe"
git push
```

- [ ] **Step 3.4: MANUAL — Spustiť spike a vykonať Probe 1**

```
flutter run -d windows
```

Po naštartovaní:
1. Klik na 🧪 FAB v Library → otvorí sa Reader Position Probe
2. Klik priečinok hore → vyber `test/fixtures/alice.epub`
3. Počkaj kým sa kniha načíta (vidíš text v reader-i nižšie)
4. **Scrollni cez prvé 2-3 kapitoly** (aby `currentValue` dostalo nejaké hodnoty)
5. Klik veľký FAB **„Run Probe 1"**
6. **Skopíruj celý log** (zelený text na čiernom pozadí) — bude obsahovať
   výsledky kandidátov A/B/C/D z code-u

- [ ] **Step 3.5: Vlož log do draft notes**

Otvor `docs/adr/0005-reader-position-resolve-draft-notes.md`, do sekcie
„Probe 1 výsledky (po T3)" vlož:

```markdown
## Probe 1 výsledky (T3, run YYYY-MM-DD)

Fixture: alice.epub
Manual scroll: prvé 2-3 kapitoly

Probe 1 log:
```
[probe1.A] currentValue.chapter.Title = "..."
[probe1.A] currentValue.chapter.HtmlContent: ... chars (raw HTML — nie text odseku N priamo)
[probe1.A] currentValue.paragraphNumber = ...
[probe1.B] tableOfContents() returned ... entries
[probe1.B] sample entry: title="..." startIndex=...
[probe1.C] generateEpubCfi() = "..."
[probe1.D] gotoEpubCfi: skip — needs running CFI from C
```

### Verdict pre Probe 1
- ✅ / ❌ — vie sa cez public API získať text odseku N (nie celej kapitoly)?
- Ktorý kandidát uspel: _____
- Konkrétna API metóda (presný getter / call): _____

### Poznámky / surprises
- ...
```

Vyplň verdict + konkrétna metóda explicitne (per review feedback — *„nielen Probe 1 ✅/❌, ale akou konkrétnou metódou"*).

- [ ] **Step 3.6: Commit log**

```
git add docs/adr/0005-reader-position-resolve-draft-notes.md
git commit -m "docs(m3-gate): Probe 1 results from manual spike run"
git push
```

---

## Task 4: Probe 2 (CONDITIONAL — len ak Probe 1 ❌)

**Cieľ:** Ak Probe 1 nevyriešil prístup k textu odseku cez API, zmerať či počty odsekov medzi epub_view a vlastnou flutter_html-style segmentáciou sedia.

**Skipni tento task ak Probe 1 vrátil ✅** (vetva 1) — choď rovno na Task 5.

**Files:**
- Create: `lib/spike/reader_position/paragraph_segmenter.dart`
- Modify: `lib/spike/reader_position/reader_position_probe_screen.dart`
- Modify: `docs/adr/0005-reader-position-resolve-draft-notes.md`

- [ ] **Step 4.1: Vytvor `lib/spike/reader_position/paragraph_segmenter.dart`**

```dart
import 'package:html/parser.dart' show parse;

/// Vlastná flutter_html-style paragraph segmentation pre alignment porovnanie.
/// Iba pre spike — produkčný kód (M3 T2+) bude robiť toto inak.
class ParagraphSegmenter {
  /// Vráti zoznam textových obsahov block-level elementov v poradí, ako by ich
  /// segmentoval flutter_html: <p>, <div>, <h1-h6>, <blockquote>, <li>, <img>.
  static List<String> segment(String rawHtml) {
    final doc = parse(rawHtml);
    final blocks = doc.querySelectorAll(
        'p, div, h1, h2, h3, h4, h5, h6, blockquote, li, img');
    return blocks
        .map((el) => el.text.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}
```

- [ ] **Step 4.2: Pridať Probe 2 do spike obrazovky**

V `reader_position_probe_screen.dart` pridaj import:

```dart
import 'package:epubx/epubx.dart' as epubx;
import 'paragraph_segmenter.dart';
```

A pridaj metódu (pred `dispose`):

```dart
  Future<void> _runProbe2() async {
    final c = _controller;
    if (c == null) {
      _logLine('[probe2] no controller — load fixture first');
      return;
    }
    _logLine('=== PROBE 2: paragraph count alignment ===');

    // Z epub_view perspektívy: posledný viditeľný paragraphNumber pre aktuálnu kapitolu.
    final cv = c.currentValue;
    if (cv == null) {
      _logLine('[probe2] currentValue null — scroll cez kapitolu najprv');
      return;
    }
    _logLine('[probe2.epubview] chapter=${cv.chapterNumber} '
        'currentParagraphNumber=${cv.paragraphNumber} '
        '(scroll na koniec kapitoly + spusti znova pre presný count)');

    // Z našej segmentácie cez epubx + paragraph_segmenter
    final book = await c.document;
    final chapters = book.Chapters ?? [];
    if (cv.chapterNumber > chapters.length) {
      _logLine('[probe2] chapterNumber out of range');
      return;
    }
    final chapter = chapters[(cv.chapterNumber - 1).clamp(0, chapters.length - 1)];
    final html = chapter.HtmlContent ?? '';
    final segments = ParagraphSegmenter.segment(html);
    _logLine('[probe2.ours] same chapter via own segmenter: '
        '${segments.length} blocks');
    if (segments.isNotEmpty) {
      _logLine('[probe2.ours] first block preview: '
          '"${segments.first.substring(0, segments.first.length.clamp(0, 60))}..."');
    }

    _logLine('=== PROBE 2 END — porovnaj counts a vlož do notes ===');
  }
```

Pridaj druhý FAB ktorý ho volá:

```dart
// V FAB Wrap-e pridaj Column children na začiatok:
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'probe2',
              tooltip: 'Run Probe 2 (alignment)',
              child: const Icon(Icons.compare_arrows),
              onPressed: _runProbe2,
            ),
```

(Súčasné usporiadanie tlačidiel uprav per potreba — môžeš mať Column s viacerými FAB.)

- [ ] **Step 4.3: Verify analyze**

```
flutter analyze
```

- [ ] **Step 4.4: Commit + push**

```
git add lib/spike/reader_position/
git commit -m "feat(m3-gate): Probe 2 alignment instrumentation"
git push
```

- [ ] **Step 4.5: MANUAL — spustiť Probe 2**

Hot-reload alebo reštart `flutter run -d windows`.

Pre KAŽDÚ zo 4 fixtures (alice, pride, frankenstein, divina):
1. Otvor fixture
2. **Scrollni úplne na koniec PRVEJ kapitoly** (aby currentValue.paragraphNumber bol = počet odsekov v kapitole 1)
3. Klik „Run Probe 2"
4. Skopíruj log
5. Vráť sa, otvor ďalšiu fixture

- [ ] **Step 4.6: Vlož výsledky do draft notes**

```markdown
## Probe 2 výsledky (T4, run YYYY-MM-DD)

| Fixture | epub_view paragraphNumber (1. kap.) | Náš segmenter (1. kap.) | Match? |
|---------|--------------------------------------|--------------------------|--------|
| alice.epub | _ | _ | ✅ / ❌ |
| pride.epub | _ | _ | ✅ / ❌ |
| frankenstein.epub | _ | _ | ✅ / ❌ |
| divina.epub | _ | _ | ✅ / ❌ |

### Verdict pre Probe 2
- ✅ Counts sedia na všetkých 4 fixtures → Vetva 2 viable
- ⚠️ Sedia len na niektorých → krehké, off-by-N, vetva 2 nestabilná
- ❌ Nesedia → Vetva 3 (renderer wall)
```

Commit:
```
git add docs/adr/0005-reader-position-resolve-draft-notes.md
git commit -m "docs(m3-gate): Probe 2 alignment results across 4 fixtures"
git push
```

---

## Task 5: scrollTo timing bonus probe

**Cieľ:** Overiť či `controller.scrollTo(index: N)` reálne pristane na očakávaný odsek hneď po `loadingState == success`, alebo či potrebuje `postFrameCallback` / retry. Šetrí debug v T7.

**Files:**
- Modify: `lib/spike/reader_position/reader_position_probe_screen.dart`
- Modify: `docs/adr/0005-reader-position-resolve-draft-notes.md`

- [ ] **Step 5.1: Pridať timing test do spike obrazovky**

Pridaj metódu:

```dart
  Future<void> _runScrollToTimingTest() async {
    final c = _controller;
    if (c == null) {
      _logLine('[scrolltest] no controller');
      return;
    }
    _logLine('=== SCROLLTO TIMING TEST ===');

    // Vol scrollTo na index 50 — niekde uprostred knihy (paragraph index)
    const targetIndex = 50;

    try {
      _logLine('[scrolltest] calling scrollTo(index: $targetIndex) IMMEDIATELY');
      await c.scrollTo(index: targetIndex);
      // Daj UI čas na settling
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final landedAt = c.currentValue?.paragraphNumber;
      _logLine('[scrolltest] after immediate call: landed at paragraph=$landedAt '
          '(expected ~$targetIndex; off by ${landedAt == null ? "?" : (landedAt - targetIndex).abs()})');
    } catch (e) {
      _logLine('[scrolltest] immediate scrollTo threw: $e');
    }

    _logLine('=== TIMING TEST END ===');
  }
```

Pridaj tretí FAB ktorý volá `_runScrollToTimingTest`.

- [ ] **Step 5.2: Verify + commit**

```
flutter analyze
git add lib/spike/reader_position/
git commit -m "feat(m3-gate): scrollTo timing test instrumentation"
git push
```

- [ ] **Step 5.3: MANUAL — spustiť timing test**

```
flutter run -d windows
```

1. Otvor alice.epub
2. **Hneď ako sa zobrazí text** (loadingState success), klik „Run scrollTo timing"
   — NIE PO SCROLLE
3. Skopíruj log

Opakuj ešte raz s **cold restart** — zatvor appku, znovu spusti, otvor, klikni
hneď.

- [ ] **Step 5.4: Vlož výsledky do draft notes**

```markdown
## scrollTo timing výsledky (T5, run YYYY-MM-DD)

### Hot path (within session, knihy už načítaná pred-tým)
- scrollTo(index: 50) → landed at: _____
- off by: _____ paragraphs
- Potreba postFrameCallback? ÁNO / NIE

### Cold start (zabi appku, spusti znova, hneď scrollTo)
- scrollTo(index: 50) → landed at: _____
- off by: _____ paragraphs
- Potreba postFrameCallback / retry? ÁNO / NIE

### Záver pre M3 implementáciu (T7)
- _(implementačná poznámka: postFrameCallback wrap, alebo immediate OK)_
```

```
git add docs/adr/0005-reader-position-resolve-draft-notes.md
git commit -m "docs(m3-gate): scrollTo timing test results"
git push
```

---

## Task 6: Konsolidácia → ADR 0005 + branch decision + cleanup

**Cieľ:** Zo všetkých probe výsledkov spísať finálne ADR, vybrať vetvu, a (pre Vetvy 1/2) zmazať spike + vrátiť dev FAB. Pre Vetvu 3 — STOP a escalate.

**Files:**
- Create: `docs/adr/0005-reader-position-resolve.md`
- Delete: `docs/adr/0005-reader-position-resolve-draft-notes.md`
- Delete: `lib/spike/reader_position/` (celý priečinok)
- Modify: `lib/app.dart` (remove dev route)
- Modify: `lib/features/library/library_screen.dart` (remove dev FAB)

- [ ] **Step 6.1: Vyhodnoť vetvu**

Z draft notes:
- Probe 1 ✅ → **Vetva 1** (alignment-free Plán B)
- Probe 1 ❌ + Probe 2 ✅ na 4/4 fixtures → **Vetva 2** (alignment-dependent Plán B/A)
- Probe 1 ❌ + Probe 2 čiastočne alebo ❌ → **Vetva 3** (renderer wall)

- [ ] **Step 6.2: AK VETVA 3 — STOP a escalate**

Ak je to Vetva 3, **NEMAŽ spike, NEPÍŠ ADR final**. Namiesto toho:

1. Aktualizuj draft notes — explicitne *„VETVA 3 — STRATEGICKÝ REVIEW POŽADOVANÝ"*.
2. Commit + push draft notes.
3. **Sumarizuj výsledok pre používateľa** (správa typu: „Probe 1 výsledok, Probe 2 výsledok, navrhujem nasledujúce možnosti: A revisit WebView renderer s opraveným crashom, B iný EPUB renderer, C re-design anchor formátu na render-coupled — vyber").
4. **STOP execution plánu**. Žiadne ďalšie tasky bez explicitného strategického rozhodnutia používateľa.

Ak je to Vetva 1 alebo 2, pokračuj Step 6.3.

- [ ] **Step 6.3: Vytvor `docs/adr/0005-reader-position-resolve.md`**

```markdown
# ADR 0005 — Reader Position Resolve (M3 GATE)

**Status:** Accepted
**Dátum:** YYYY-MM-DD
**Kontext:** M3 spec `docs/specs/m3-reader-v1.md` §5
**Related:** ADR 0002 (anchor format)

## Kontext

M3 reader staví resume pozície na `ReadingPositionAnchor` (M2.5). Otvorenou
otázkou bolo ako resolve `(chapterId, charOffset)` → scroll pozícia v
`EpubView`. M3 spec §5 definoval trojvetvový rozhodovací strom; tento ADR
zachytáva ktorá vetva bola vybraná na základe Step 0 probe-ov.

## Probe 1 — paragraph text via API

**Verdict: ✅ / ❌**

**Konkrétna API metóda použitá (pre Vetvu 1):** _(presný getter / call,
vrátane verzie balíka — toto je upgrade-fragility point)_

Detaily: viď draft notes pre raw log.

## Probe 2 — paragraph alignment (ak Probe 1 ❌)

| Fixture | epub_view count | Náš segmenter count | Match |
|---------|-----------------|---------------------|-------|
| alice.epub | _ | _ | ✅ / ❌ |
| pride.epub | _ | _ | ✅ / ❌ |
| frankenstein.epub | _ | _ | ✅ / ❌ |
| divina.epub | _ | _ | ✅ / ❌ |

## scrollTo timing

- Hot path: scrollTo immediate → off by _____
- Cold start: scrollTo immediate → off by _____
- **Záver:** postFrameCallback wrap potrebný / nepotrebný

## Rozhodnutie

**Vybraná vetva: Vetva 1 / 2**

(Vetva 3 by neviedla k tomuto ADR — viedla by k strategickému reviewu.)

### Implementačná cesta pre Vetvu 1 (alignment-free Plán B)

1. Compute anchor pri scroll:
   - Z currentValue zobrať aktuálny paragraph
   - Cez API metódu `<konkrétna metóda z Probe 1>` získať text odseku
   - Vyhľadať quote v CanonicalChapterText → charOffset
   - Uložiť ako ReadingPositionAnchor

2. Resolve:
   - Z anchora dorátaj quote (alebo použi transient pole)
   - Iteruj epub_view paragraphs v kapitole (cez API metódu z Probe 1)
   - Nájdi prvý ktorého text obsahuje quote
   - scrollTo(absoluteParagraphIndex)
   - Wrap v postFrameCallback ak Probe 5 ukázal že treba

### Implementačná cesta pre Vetvu 2 (alignment-dependent Plán B/A)

(Rovnaké ako Vetva 1, ale text odseku príde z vlastného `ParagraphSegmenter`
namiesto epub_view API. Závisí od trvalej alignment zhody s flutter_html.)

**Vetva 2 dodatočné konštrašné opatrenia:**

- `flutter_html` pin v `pubspec.yaml` musí byť **prísnejší než caret** — fix
  na konkrétnu minor verziu. Pri upgrade prejsť alignment testom.
- Pridať regression test `test/features/reader/paragraph_alignment_test.dart`
  ktorý kontroluje že počty odsekov medzi vlastnou segmentáciou a epub_view
  (cez nejakú heuristiku — napr. cez `EpubChapter` parser výsledok) sedia
  na 4 fixtures. Zlyhanie tohto testu = blocker pre release.

## Dôsledky

- M3 T2-T11 stavajú PositionResolver na zvolenej vetve.
- Pri upgrade `epub_view` musí Probe 1 znova prebehnúť (zmena API metódy by
  zlomila resolver). Toto pravidlo zaznamenané v poznámke v
  `lib/features/reader/position_resolver.dart` (vznikne v T4).
- (Vetva 2 only) `flutter_html` upgrade vyžaduje paragraph alignment re-test.

## Alternatívy zamietnuté

- **Native paragraph index ako anchor** — render/library-dependent, rozbil by
  cross-device sync. ADR 0002 už túto cestu zamietol; ADR 0005 to len
  potvrdzuje implementačne.
- **WebView renderer (Vetva 3)** — len ak GATE viedol na renderer wall.
  Aktuálne nevybrané.
```

Vyplň konkrétne hodnoty zo všetkých probe výsledkov.

- [ ] **Step 6.4: Zmaž draft notes**

```
rm docs/adr/0005-reader-position-resolve-draft-notes.md
```

- [ ] **Step 6.5: Zmaž spike folder**

```
rm -rf lib/spike/reader_position/
```

Ak je `lib/spike/` prázdny, zmaž ho tiež.

- [ ] **Step 6.6: Vyčisti dev route v `lib/app.dart`**

Odstráň import `spike/reader_position/reader_position_probe_screen.dart`.
Odstráň `/dev/reader_position_probe` case z `onGenerateRoute` (analogicky ako M2.5 T9).

- [ ] **Step 6.7: Vyčisti dev FAB v `lib/features/library/library_screen.dart`**

Vráť `floatingActionButton` na pôvodnú extended verziu (bez Column s dev FAB).
Per analógia s M2.5 T9 cleanup.

- [ ] **Step 6.8: Verify**

```
flutter analyze
flutter test
flutter build windows --debug    # background, timeout 300000
```

- [ ] **Step 6.9: Commit + push**

```
git add -A
git status
```

Verify staged: `docs/adr/0005-reader-position-resolve.md` (new), deleted draft notes, deleted spike folder, modified app.dart + library_screen.dart.

```
git commit -m "docs(m3-gate): ADR 0005 finalised + spike cleanup (Vetva <N>)"
git push
```

---

## Akceptačné kritériá T1 GATE

- [ ] `docs/adr/0005-reader-position-resolve.md` napísaný s konkrétnymi probe výsledkami
- [ ] **Konkrétna API metóda** (pre Vetvu 1) explicitne dokumentovaná v ADR — nielen Yes/No
- [ ] Branch decision (Vetva 1 / 2) zapísaný v ADR
- [ ] Spike `lib/spike/reader_position/` zmazaný
- [ ] `lib/app.dart` + `lib/features/library/library_screen.dart` vrátené do pred-T1 stavu
- [ ] `flutter analyze` clean, `flutter test` pass, `flutter build windows --debug` builds
- [ ] **AK VETVA 3:** spike NEzmazaný, ADR final NEnapísaný, používateľovi poslaný výsledok + návrhy na strategický review. Žiadne ďalšie tasky.

## Po T1

- **Vetva 1 alebo 2:** napíšem detailný plán pre T2-T11 cez `superpowers:writing-plans` skill, s konkrétnou implementáciou PositionResolver pre zvolenú vetvu.
- **Vetva 3:** strategický review s používateľom — žiadny ďalší plán bez rozhodnutia.
