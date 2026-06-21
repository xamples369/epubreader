# ADR 0002 — Render-Agnostic Anchor Format

**Status:** Accepted
**Dátum:** 2026-06-21
**Kontext:** M2.5, Fáza 1 (MVP)
**Supersedes:** —
**Related:** ADR 0001 (renderer choice), `docs/specs/m2.5-anchor-format.md`,
`docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md`

---

## Kontext

Spec `m2.5-anchor-format.md` identifikoval že bez stabilnej reflow-nezávislej
kotvy nemá zmysel budovať highlighty (Fáza 3) ani sync (Fáza 5). Toto ADR
zafixuje výsledné rozhodnutia po S0–S7 implementácii.

## S0 GATE — Canonical-text consistency výsledky

**Test:** manuálne (`lib/spike/anchor_probe/`) — používateľ napíše frázu z čítača,
appka overí či sa nájde v canonical-text (epubx + normalize) tej istej kapitoly.

| Fixture | Fráz testovaných | ✅ | ❌ | Poznámky |
|---------|-----------------|----|----|----------|
| alice.epub | ~5 | ~5 | 0 | Prvý fail bol typografickými úvodzovkami (curly „" vs straight ""), reconciliation pridaná → ✅ |
| pride.epub | ~5 | ~5 | 0 | OK |
| frankenstein.epub | ~5 | ~5 | 0 | OK |
| divina.epub | ~5 | ~5 | 0 | OK aj s talianskou diakritikou (`è à ò`) |

**S0 GATE: PASSED** ✅

### Reconciliation pravidlá objavené počas S0

Pôvodný `normalize` strip-oval len soft hyphens a whitespace. Pri reálnom teste
vyšlo najavo že EPUB knihy bežne používajú **typografické varianty** ktoré
používateľ pri ručnom písaní nereprodukuje:

- `"` `"` `„` `«` `»` → `"`  (smart double quotes + guillemets)
- `'` `'` `‚` → `'`  (smart single quotes / apostrofy)
- `–` `—` → `-`  (en/em dash → ASCII hyphen)
- `…` → `...`  (horizontal ellipsis)

Pravidlá sú aplikované na **obe strany** (canonical text aj user input).
Súbory: `lib/domain/anchor/canonical_chapter_text.dart` a
`lib/domain/anchor/anchor_codec.dart` (metóda `normalize`).

## EpubController API zistenia (S1, statická analýza)

`epub_view ^3.2.0` poskytuje cez `EpubController`:

| Info | Dostupné? | API | Kvalita |
|------|-----------|-----|---------|
| Aktuálna kapitola (EpubChapter) | ✅ | `controller.currentValue?.chapter` | dobré (má Title, ContentFileName, HtmlContent) |
| Manifest href | ✅ | `controller.currentValue?.chapter?.ContentFileName` | dobré |
| Spine index kapitoly | ✅ | `controller.currentValue?.chapterNumber` | dobré |
| Paragraph index v kapitole | ✅ | `controller.currentValue?.paragraphNumber` | dobré (1-based) |
| Scroll position | ✅ | `controller.currentValue?.position` (ItemPosition) | pixel-based |
| Listener zmeny pozície | ✅ | `controller.currentValueListenable` | ValueNotifier |
| TOC | ✅ | `controller.tableOfContents()` | dobré |
| **Programmatic scroll na paragraph index** | ✅ | `controller.scrollTo(index: N)` / `jumpTo(...)` | dobré |
| **Programmatic scroll na char N v kapitole** | ❌ | žiadne priame API | char → paragraph mapping musíme dorátať sami |
| **`generateEpubCfi()`** | ✅ | `controller.generateEpubCfi() → String?` | BONUS — vie CFI |
| **`gotoEpubCfi(cfi)`** | ✅ | rýchla cesta na CFI | BONUS |
| Init s pozíciou | ✅ | `EpubController(document, epubCfi: '...')` | dobré |
| Selection / onSelectionChanged | ❌ | nie je vystavené | pre Fázu 3 treba `SelectionArea` wrap alebo vlastný UI flow |

## Rozhodnutia

### 1. Dva anchor formáty

- **`ReadingPositionAnchor`** — `(chapterId, charOffset, chapterLength)`
  v normalizovanom texte kapitoly. Render-agnostické.
- **`HighlightAnchor`** — `(chapterId, quote, prefix, suffix, charOffset?)`
  W3C TextQuoteSelector-style.

### 2. `chapterId`

- **Primárne:** `manifest href` (napr. `OEBPS/Text/ch1.xhtml`).
- **Fallback:** `#<spineIndex>` (string s prefixom `#`).
- **Scope:** anchor sa resolve-uje len v EPUB súbore s rovnakým content
  hash-om. **Cross-edícia explicitne nepodporovaná** — vyrieši ADR 0003
  (book-identity).

### 3. Single source of truth pre text kapitoly

`CanonicalChapterText.extract(book, chapterId)` v `lib/domain/anchor/`.
Používa to OBE `createHighlight` AJ `findHighlight` — žiadny rozdiel medzi
render-text streamom (epub_view + flutter_html) a parse-text streamom (epubx).

### 4. String-first API

`createHighlight` prijíma `EpubBook + chapterId + rawSelectedText + rawPrefix +
rawSuffix`. Žiadne offset mapping medzi raw a normalised textom — pracujeme
s reťazcami.

### 5. Fuzzy algoritmus

**Sliding alignment** (Smith-Waterman-style local match):
- Needle kĺže cez okno `±500` znakov okolo `charOffset` hint.
- Pre každú pozíciu skúšame dĺžky `needle.length ± 10` (povolené inserts/deletes).
- `similarity = 1 - editDistance / needle.length` (menovateľ = needle, NIE okno).
- Threshold: `≥ 0.92` (cca 16 zmien v 200-znakovom citáte).
- Tie-break: vyšší similarity → najbližšie k charOffset → najskoršia pozícia.

### 6. Reading position resolve: Plán A (s mid-task mappingom)

- Controller scrolluje na paragraph index, nie char.
- Z `charOffset` v canonical-text vieme odvodiť paragraph cez prechod
  chapters → paragraphs s kumulatívnym char count (per-chapter pre-compute
  pri prvom otvorení knihy).
- **Plán B (degenerated highlight)** je vždy dostupný fallback ak Plán A zlyhá.
- **Bonus Plán C (CFI hybrid)** — `generateEpubCfi()` na save, `gotoEpubCfi()`
  na load — môžeme uložiť CFI ako transient cache na zariadení pre fast resolve.
  Neserializuje sa do cloudu (CFI je epub_view-specific; nesync-uje sa).

### 7. Sync merge — furthest-read-wins

`(spine_index, charOffset)` lex order ako default pre reading position.
„Last wins" alternatíva odložená na Fázu 5 Settings.

### 8. Annotation record polia (pre Fázu 3)

`HighlightAnchor` je čistý lokátor. Annotation **record** musí mať polia:
- `id` (client-generated UUID v4 — pre sync deduplication)
- `bookId`
- `anchor` (HighlightAnchor ako JSON)
- `note?`, `colorIndex?`
- `createdAt`, `updatedAt` (LWW pre editácie)
- `deviceId` (sync attribution)
- `isDeleted` (soft-delete tombstone)

Bez týchto polí Fáza 5 nedokáže deduplicate, merge editácie, ani replikovať
deletions. Fáza 3 schéma MUSÍ obsahovať od začiatku.

## Dôsledky

- **M3 (Reader v1)** prepíše tabuľku `reading_positions` — drop `chapterIndex`
  a `progressInChapter` REAL → pridať `anchor_json TEXT`. Migration je triviálna.
- **Fáza 3 (anotácie)** stavia schému s vyššie uvedenými poliami od začiatku;
  ukladá `HighlightAnchor` ako JSON v `annotations.anchor` stĺpci.
- **Fáza 5 (sync)** prenáša anchory v append-only event log entries; merge
  logika na klientovi je deterministická (`furthestRead` pre RP, UUID + LWW
  pre highlighty).
- **Highlight tvorba v M3+** — `epub_view` nemá natívny selection callback.
  Buď wrap-neme `EpubView` v `SelectionArea` (test-needed), alebo postavíme
  vlastný UI flow (tap → start/end picker). Toto je M3+ výzva.

## Alternatívy zamietnuté

- **CFI via WebView (flutter_epub_viewer)** — crash na Windows (ADR 0001).
  CFI ako cache cez `epub_view` ostáva ako bonus.
- **Paragraph index ako anchor** — nestabilné pri reflow.
- **`progress * render_height`** — render-závislé (telefón vs PC dáva inú výšku).
- **`max(progress)` per book bez spine ordering** — nesprávne pri ordering
  medzi kapitolami.
- **Single unified anchor pre RP aj highlight** — diametrálne odlišné conflict
  resolution semantics.
- **Render text z flutter_html ako kanonický zdroj** — divergencia s epubx
  parse-textom by spôsobila že anchor sa systematicky nenájde pri resolve.

## Mileniky implementácie

| ID | Cieľ | Commit |
|----|------|--------|
| Spec written | Spec napísaný | `7f9a607` |
| Spec review 1 | Incorporate P1-P3 feedback | `e8720ad` |
| Spec review 2 | render/parse divergence + sliding fuzzy fix | `e0e7bcc` |
| Spec review 3 | S0 gate elevated to first | `e935784` |
| Plan written | 9-task implementation plan | `317e632` |
| **S0 GATE** | Canonical-text consistency on 4 fixtures | `631727d`, `ce947da`, `00c62f5`, `30323b6` |
| **S1** | EpubController API investigation | `eba53df` |
| **S2** | CanonicalChapterText extractor | `44c9419` |
| **S3** | Anchor data classes + JSON + furthestRead (bundles S7) | `9870965` |
| **S4** | AnchorCodec.normalize + createHighlight | `f082a26` |
| **S5** | findHighlight exact + disambiguation | `147e748` |
| **S6** | Sliding fuzzy match | `5a909ee` |
| **S8** | This ADR + cleanup spike + README | (pending) |

## Testy

`test/domain/anchor/` má 7 test súborov s celkovo **35 testami**, všetky pass.
Pokrýva: canonical extract determinism + fixture coverage + typographic
normalize, anchor JSON round-trip, furthestRead merge ordering, normalize
edge cases, createHighlight cap rules + canonical hint, findHighlight exact
+ disambiguation + diacritics, sliding fuzzy insert/delete tolerance +
threshold reject.
