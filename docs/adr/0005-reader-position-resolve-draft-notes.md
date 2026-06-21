# ADR 0005 draft notes — M3 GATE

> Pracovný dokument pre M3 GATE. Po T6 sa konsoliduje do `docs/adr/0005-reader-position-resolve.md` a tento súbor sa zmaže.

---

## Task 1 — epub_view API surface inventory (2026-06-21)

### Public surface relevantná pre paragraph text access

**`EpubController`** (`lib/src/epub_controller.dart`):

| API | Návratový typ | Hodnota pre Probe 1 |
|-----|---------------|---------------------|
| `currentValue` | `EpubChapterViewValue?` | chapter object + chapterNumber + paragraphNumber (chapter-relative, 1-based) + position. **NIE text odseku N priamo.** |
| `currentValueListenable` | `ValueNotifier<EpubChapterViewValue?>` | listener pre scroll zmeny. |
| `loadingState` | `ValueNotifier<EpubViewLoadingState>` | loading/success/error. |
| `tableOfContents()` | `List<EpubViewChapter>` | per-chapter `{title, startIndex}` kde startIndex je absolútny flatParagraphs index. Žiadny text odseku. |
| `tableOfContentsListenable` | rovnaké ako ↑ | |
| `jumpTo(index, alignment)` | `void` | scroll na **absolútny** flatParagraphs index. |
| `scrollTo(index, duration, alignment, curve)` | `Future<void>?` | scroll na **absolútny** flatParagraphs index. |
| `generateEpubCfi()` | `String?` | CFI pre aktuálnu top pozíciu. Použiteľné na alt-route, NIE text odseku. |
| `gotoEpubCfi(cfi)` | `void` | scroll na CFI. |

**`EpubChapterViewValue`** (`lib/src/data/models/chapter_view_value.dart`):
```dart
class EpubChapterViewValue {
  final EpubChapter? chapter;     // raw HTML kapitoly cez .HtmlContent
  final int chapterNumber;        // 1-based, FLAT (per parseChapters: includes subchapters)
  final int paragraphNumber;      // 1-based, CHAPTER-RELATIVE
  final ItemPosition position;    // index (absolute paragraph), leadingEdge, trailingEdge
  double get progress;            // render-based %
}
```

**`EpubViewChapter`** (`lib/src/data/models/chapter.dart`):
```dart
class EpubViewChapter {
  final String? title;
  final int startIndex;           // absolute flatParagraphs index
}
class EpubViewSubChapter extends EpubViewChapter { ... }
```

### CRITICAL: `Paragraph` class existuje, ale `_paragraphs` list je private

**`Paragraph`** (`lib/src/data/models/paragraph.dart`):
```dart
class Paragraph {
  final dom.Element element;      // html package DOM element → .text vráti čistý text odseku
  final int chapterIndex;
}
```

**`parseParagraphs`** (`lib/src/data/epub_parser.dart`) — top-level public funkcia:
```dart
ParseParagraphsResult parseParagraphs(
  List<EpubChapter> chapters,
  EpubContent? content,
) { ... }

class ParseParagraphsResult {
  final List<Paragraph> flatParagraphs;   // VŠETKY paragraphs naprieč kapitolami
  final List<int> chapterIndexes;          // offset v flatParagraphs kde každá kapitola začína
}
```

**`parseChapters`** (`lib/src/data/epub_parser.dart`) — top-level public:
```dart
List<EpubChapter> parseChapters(EpubBook epubBook) =>
  epubBook.Chapters!.fold([], (acc, next) {
    acc.add(next);
    next.SubChapters!.forEach(acc.add);    // ZAHŔŇA SUBCHAPTERS — flat list
    return acc;
  });
```

### Kde sa flatParagraphs používa interne v EpubView

`lib/src/ui/epub_view.dart`:
```
line 61:  List<Paragraph> _paragraphs = [];          // PRIVATE state field
line 64:  final _chapterIndexes = <int>[];           // PRIVATE state field
line 106: _paragraphs = parseParagraphsResult.flatParagraphs;
line 107: _chapterIndexes.addAll(parseParagraphsResult.chapterIndexes);
line 139: paragraphNumber: paragraphIndex + 1,       // CHAPTER-RELATIVE, 1-based
line 254-283: paragraphIndex = posIndex - _chapterIndexes[index];  // absolute → relative conversion
line 377: itemCount: _paragraphs.length,
```

### Závery pre GATE — predispute starého modelu

Pôvodný GATE strom hovoril:
- Vetva 1 = paragraph text dostupný cez **public API** (alignment-free)
- Vetva 2 = nutné vlastné parsovanie, alignment-dependent (fragile)
- Vetva 3 = ani jedno

**Nálezy menia obraz:**

- **Vetva 1 (strict public API): NIE JE DOSTUPNÁ.** `_paragraphs` je private,
  `EpubController` ho nevystavuje, `currentValue` len chapter+paragraphNumber+position.
- **ALE** `parseParagraphs` a `parseChapters` sú **top-level public funkcie**
  exportované z `package:epub_view/src/data/epub_parser.dart`. Môžeme ich
  ZAVOLAŤ a získať **byte-identický** `List<Paragraph>` aký EpubView má interne.
  - Caveat: import z `package:.../src/...` je v Dart konvencii „discouraged",
    nie zakázaný. Funkcia je čisto public, import je technicky validný, len
    semanticky signalizuje „autor zaručuje stabilitu len pre top-level
    `lib/<package>.dart` export-y".
- **Strict vlastná reimplementácia (Vetva 2 ako bola v spec-e)** je krehká
  — algoritmus `_removeAllDiv` + `getElementsByTagName('body').first.children`
  + chapter anchor handling sa môže pri minor epub_view upgrade zmeniť.

### Nový rozhodovací priestor

| Vetva | Cesta | Garancia alignment-u | Riziko |
|-------|-------|----------------------|--------|
| ~~1 (strict public API)~~ | — | — | **NIE JE MOŽNÁ** (private state) |
| **1.5 (src/ import)** | `parseParagraphs` z `package:epub_view/src/data/epub_parser.dart` | **By construction** (rovnaký kód) | Discouraged import konvencia; pin epub_view verziu; major upgrade = re-verify |
| 2 (reimplementácia) | Vlastný segmenter, manuálne udržiavaný alignment s flutter_html | Manuálna, fragile | Akýkoľvek upgrade ktorejkoľvek strany = potenciálny drift |
| 3 (renderer wall) | — | — | Strict public API failed AND src/ import neakceptujeme |

### Index spaces (kritické pre Probe / scrollTo timing)

- `currentValue.paragraphNumber` = **chapter-relative, 1-based** (per line 139)
- `currentValue.position.index` = **absolute flatParagraphs index**
- `scrollTo(index: N)` / `jumpTo(index: N)` = **absolute flatParagraphs index**
- `tableOfContents().startIndex` = **absolute** (offset prvého paragraph-u kapitoly)

**Pôvodný scrollTo timing test v pláne porovnával `paragraphNumber` (chapter-rel)
proti `index: 50` (absolute) — apples-to-oranges**, ako varoval review.

**Konverzia:** pre kapitolu C s `tableOfContents()[C-1].startIndex = S`:
- absolute = S + (paragraphNumber - 1)
- (alebo priamo `position.index`)

---

## DECISION (2026-06-21, po user review): **Vetva 1.5 akceptovaná**

### Reframe ktorý túto voľbu robí korektnou (nie kompromisom):

Aj Vetva 1.5 aj Vetva 2 závisia od interného správania epub_view parsera.
Rozdiel je len v tom **ako sa tá závislosť prejaví pri zmene**:

- **Vetva 2 (reimplementácia):** závislosť ktorá sa láme **ticho** — náš vlastný
  segmenter driftne od ich verzie, kód sa stále kompiluje, beží, len produkuje
  subtílne zlé kotvy.
- **Vetva 1.5 (priame volanie tej istej public funkcie):** závislosť ktorá sa láme
  **nahlas** — zmena signatúry = compile error, zmena správania = alignment probe
  zlyhá pri re-verify.

Hlasné zlyhanie je striktne bezpečnejšie než tiché, obzvlášť pri kotvách ktoré
majú byť render-agnostické a prenosné. Identický pattern ako html package v M2.6.

### 4 podmienky platnosti Vetvy 1.5 (všetky NUTNÉ)

1. **Single adapter file** — `lib/spike/reader_position/epub_view_paragraph_bridge.dart`
   (a po cleanup-e production location). Jeden blast radius. Thick comment
   s rationale + pin-and-reverify pravidlom.
2. **Pin epub_view strictly** v `pubspec.yaml` (nie caret cez minor) + ADR pravidlo:
   akýkoľvek epub_view bump = re-run alignment probe pred merge.
3. **Probe MUSÍ dokázať ekvivalenciu, nie ju predpokladať.** Najmä na divina
   (štruktúrované so SubChapters — presne tam kde by extra post-processing v
   `_EpubViewState` mohol prejaviť). Falošný positive na alice + fail na divina =
   rozbité kotvy pre štruktúrované knihy.
4. **Permanent regression test** v T2+ (production) — chytá prípad keď budúca
   verzia epub_view zmení interný post-processing tak že `_paragraphs ≠
   parseParagraphs(...)` aj keď náš kód stále kompiluje.

### Bonus follow-up (cleanup path)

Filovať upstream issue/PR na epub_view na vystavenie `flatParagraphs` ako
public API. Ak autor mergne → dropneme src/ import → čistá Vetva 1. ~20 min
práce, dáva clean exit path namiesto trvalého couplingu na internals.
Uložené ako memory note `project_epub_view_upstream_issue.md`.

### Revidovaný Probe 1 dizajn

Pôvodné A/B/C/D kandidáti **DROP**. Nový probe:

1. **Bridge:** `EpubViewParagraphBridge.extractFlatParagraphs(book)` cez
   `parseChapters` + `parseParagraphs` zo src/ importu → vráti
   `ParseParagraphsResult { flatParagraphs, chapterIndexes }`.
2. **EpubView side:** počkaj `loadingState == success`, vezmi
   `controller.tableOfContents()` — to vystavuje **absolútne** chapter startIndex-y.
3. **Ekvivalencia probe (deterministická, žiadny manual scroll):**
   - Porovnaj `bridge.chapterIndexes.length` vs `viewToc.length`
   - Per kapitola: `bridge.chapterIndexes[i]` musí presne sedieť s
     `viewToc[i].startIndex`. Ak hocijaký chapter má rozdiel → Vetva 1.5
     equivalence NEdokázaná → escalate (Vetva 3 v starom modeli).
4. Spusti na všetkých 4 fixtures, najmä **divina**.

Toto je striktne lepšie než pôvodný manual-scroll Probe 2 — deterministické,
rýchle, jednoznačné, pokrýva subchapters cez `parseChapters` fold logiku.
