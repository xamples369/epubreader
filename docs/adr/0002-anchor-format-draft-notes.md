# ADR 0002 draft notes — výsledky S0–S7

> Pracovný dokument. Po S8 sa konsoliduje do finálneho `docs/adr/0002-anchor-format.md` a tento súbor sa zmaže.

---

## S0 GATE — Canonical-text consistency (2026-06-21)

**Test setup:** spike `lib/spike/anchor_probe/` — používateľ napíše frázu z čítača,
appka overí či sa nájde v canonical-text (epubx + normalize) tej istej kapitoly.

### Výsledky

| Fixture | Fráz testovaných | ✅ | ❌ | Poznámky |
|---------|-----------------|----|----|----------|
| alice.epub | ~5 | ~5 | 0 | Prvý fail bol typografickými úvodzovkami (curly „" vs straight ""), reconciliation pridaná → ✅ |
| pride.epub | ~5 | ~5 | 0 | OK |
| frankenstein.epub | ~5 | ~5 | 0 | OK |
| divina.epub | ~5 | ~5 | 0 | OK aj s talianskou diakritikou (`è à ò`) |

**S0 GATE: PASSED** ✅ — pokračujeme S1.

### Reconciliation pravidlá objavené počas S0

Pôvodný `normalize` strip-oval len soft hyphens a whitespace. Pri reálnom teste
vyšlo najavo že EPUB knihy bežne používajú **typografické varianty** ktoré
používateľ pri ručnom písaní nereprodukuje (klávesnica produkuje straight
úvodzovky a bežný hyphen):

- `"` `"` `„` `«` `»` → `"`  (smart double quotes + guillemets)
- `'` `'` `‚` → `'`  (smart single quotes / apostrofy)
- `–` `—` → `-`  (en/em dash → ASCII hyphen)
- `…` → `...`  (horizontal ellipsis)

Pravidlá sú aplikované na **obe strany** (canonical text aj user input).
Súbor: `lib/spike/anchor_probe/inline_canonical_extractor.dart` a
`anchor_probe_screen.dart`. **Tieto pravidlá MUSIA prejsť do produkčného
`AnchorCodec.normalize` v T5.**

### Implications pre spec / ADR 0002

- §4.4 spec-u uvádza že lowercase/diakritika/punctuation sa NESTRIP-ujú.
  Typografické normalizácie tam nie sú explicitne. **Ide o niečo medzi:**
  zachovávame *sémantiku* punctuation (rozdiel medzi „." a „!"), ale
  *normalizujeme variantné kódovanie* tej istej sémantiky (smart vs straight
  quote ≈ ten istý čitateľský zámer). Toto je správne — užívateľské search aj
  resolve fungujú podľa zámeru, nie podľa byte-level reprezentácie.
- ADR 0002 musí toto pravidlo explicitne dokumentovať.

---

## S1 — EpubController API investigation (2026-06-21)

**Metóda:** statická analýza zdroja `epub_view-3.2.0/lib/src/`. Dynamický test
preskočený — statika dala kompletný obraz, ďalší manuálny test by bol low value.

### Verejné API `EpubController`

| Info | Dostupné? | API | Kvalita |
|------|-----------|-----|---------|
| Aktuálna kapitola (EpubChapter object) | ✅ | `controller.currentValue?.chapter` | dobré — má Title, ContentFileName, HtmlContent |
| Aktuálna kapitola (manifest href / ContentFileName) | ✅ | `controller.currentValue?.chapter?.ContentFileName` | dobré |
| Aktuálna kapitola (číselný index) | ✅ | `controller.currentValue?.chapterNumber` | dobré |
| Paragraph index v kapitole | ✅ | `controller.currentValue?.paragraphNumber` | dobré (1-based) |
| Scroll offset / position info | ✅ | `controller.currentValue?.position` (ItemPosition: index, itemLeadingEdge, itemTrailingEdge) | dobré ale pixel-based |
| Progress v kapitole (%) | ✅ | `controller.currentValue?.progress` (computed getter) | render-závislý % |
| Listener zmeny pozície | ✅ | `controller.currentValueListenable` (ValueNotifier) | dobré |
| Listener loading state | ✅ | `controller.loadingState` | dobré |
| TOC (table of contents) | ✅ | `controller.tableOfContents()` + `tableOfContentsListenable` | dobré |
| **Programmatic scroll na paragraph index** | ✅ | `controller.scrollTo(index: N)` / `jumpTo(index: N)` | dobré |
| **Programmatic scroll na char offset** | ❌ | žiadne priame API | — |
| **`generateEpubCfi()`** | ✅ | `controller.generateEpubCfi()` → String? CFI | BONUS — vrátí CFI pre aktuálnu top pozíciu |
| **`gotoEpubCfi(cfi)`** | ✅ | `controller.gotoEpubCfi(cfi)` | BONUS — rýchla cesta na CFI pozíciu |
| Init s pozíciou | ✅ | `EpubController(document: ..., epubCfi: '...')` | dobré |
| Selection / onSelectionChanged | ❌ | nie je vystavené | **fallback:** `SelectionArea` wrapper alebo úplne iný UI flow pre highlight tvorbu (do M3/Fáza 3) |

### Plán A vs Plán B pre RP resolve (§4.1)

**Plán A (priame char → scroll):**
- Controller scrolluje na **paragraph index** (`scrollTo(index: N)`), nie na char offset.
- Z char offset v canonical-text vieme odvodiť paragraph cez prechod chapters → paragraphs
  s kumulatívnym char count (per-chapter pre-compute pri prvom otvorení knihy).
- **Funguje — Plán A je realizovateľný** s mid-task mapping krokom.

**Plán B (degenerovaný HighlightAnchor):**
- Pri save: vezmi prvých ~64 znakov okolo aktuálnej top pozície ako quote.
- Pri resolve: `findHighlight(...)` → char range → mapuj na paragraph → scroll.
- Vždy funguje, mierne pomalšie (text search), ale je to fallback v každom prípade
  ak by Plán A zlyhal pri konkrétnej knihe.

**Bonus Plán C (CFI hybrid):**
- Naviac k char-offset anchor uložiť aj **CFI cache** ako transient pole.
- Save: `controller.generateEpubCfi()`, ulož v anchore ako neserialisable field
  (nepatrí do JSON — CFI je epub_view-specific a nesync-uje sa medzi rendererom).
- Load: skús `controller.gotoEpubCfi(cfi)` najprv (fast path); pri zlyhaní
  fallback na char offset → paragraph (Plán A).

### Rozhodnutie pre ADR 0002

**Primárna stratégia: Plán A** — char offset v canonical-texte mapped na paragraph
index pri resolve. Toto je rendererom prenositeľné cez sync.

**Voliteľná optimalizácia (M3+): Plán C** — CFI sa môže uchovať lokálne ako cache
pre fast resolve na tom istom zariadení. Nesynchronizuje sa do cloudu (epub_view-
specific). Tým si nezviažeme ruky pri prípadnej zmene renderera.

**Highlight tvorba** — `epub_view` nemá selection callback. Pre Fázu 3 buď
wrap-neme `EpubView` v `SelectionArea` (ak to akceptuje), alebo postavíme
vlastný UI flow (tap → pop-up s "select start/end" workflow). To je výzva pre
M3+, nie pre M2.5.

---

---

## S2-S7 commit SHAs

_(vznikne počas T3-T8)_

---

## Plán A vs Plán B pre RP resolve

_(rozhodnutie po S1 spike-u)_
