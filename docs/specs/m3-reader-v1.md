# M3 — Reader v1 (Scroll Mode) — Spec

**Status:** Draft — čaká na review používateľa
**Dátum:** 2026-06-21
**Predchádza:** M2.6 (book identity)
**Nasleduje:** M3.5 (themes + fonts) → M4 (pagination)

---

## 1. Cieľ

Postaviť **funkčnú čítačku** ktorá dokáže:

1. Otvoriť EPUB knihu z knižnice
2. Scroll-ovať jej obsah (PC kolieskom myši / šípkami, mobil swipe-om)
3. **Auto-uložiť pozíciu** cez `ReadingPositionAnchor` (M2.5) do Drift DB
4. **Auto-resume** na uloženej pozícii pri ďalšom otvorení tej istej knihy
5. Dark mode toggle (jediný theming feature v M3)
6. Reader chrome (top + bottom bar, tap-toggle)

Po M3 má používateľ **prvý raz reálne použiteľnú čítačku** — môže ňou denne
čítať knihy z knižnice (s vedomými obmedzeniami v dogfood scope, viď §9).

## 2. Strategický kontext

### Prečo tight M3 a spike-first

Front-loadnuť **najväčšie zostávajúce neznáme**: vie `epub_view` controller
resolve-núť `ReadingPositionAnchor.charOffset` na scroll pozíciu, a ako?
ADR 0002 nechal otvorenú voľbu medzi:

- **Plán A:** priame char→paragraph→scroll mapping
- **Plán B:** degenerated highlight (`findHighlight` → range → mapuj na paragraph)

Toto rozhodnutie sa rieši **v Task 1 ako GATE**, nie zabalené s theming/fonts.
Ak by sa ukázalo že ani jeden plán nestačí, fat M3 by nás stál vyhodené UI/theming
úsilie. Tight M3 chráni investíciu.

### Prečo dark mode toggle vnútri tight M3 (a nie v M3.5)

Tight M3 cieľ je „dogfood reálnymi knihami a daj feedback". Bez dark mode appku
večer nepoužiješ → nedogfood-uješ → cieľ M3 zlyháva. Dark/light toggle je
jediná theming vec ktorá rozhoduje či sa appka vôbec použije. Zvyšok (sépia,
slider jasu, fonty, settings panel) má čas v M3.5.

### Feedback contract pre dogfooding

Pri vlastnom testovaní explicitne sledovať:

- ✅ Resume na správnej pozícii
- ✅ Vernosť renderu (text čitateľne, diakritika, obrázky)
- ✅ Stabilita (žiadne crashes, freezes)

A explicitne **NEsledovať**:

- ❌ Estetiku
- ❌ Že font sa nedá meniť
- ❌ Že nie sú témy (len dark toggle)
- ❌ Že nie je TOC / záložky / vyhľadávanie

To je M3.5 a M5+. Bez tohto contractu by feedback z dogfoodu zaplavila
estetika a prekryla signál o ktorý reálne v M3 ide.

---

## 3. Rozsah

### V M3

- Reader screen s `EpubView` renderingom (otvorenie + scroll)
- `ReadingPositionsDao` (M2 tabuľka `reading_positions` existuje, dao nie)
- `PositionResolver` — Plán A alebo Plán B impl (rozhodne T1 GATE)
- `PositionPersister` — debounced save (1.5 s nehybnosti)
- `ReaderScreen` UI: render area + top bar + bottom bar s progress %
- Tap-toggle chrome (default skryté)
- Dark mode toggle (top bar icon) + persistencia cez `SettingsKvDao`
- Resume flow pri otvorení knihy
- ADR 0005 s rozhodnutím Plán A vs B
- Integrácia `BookIdentity.compute` (M2.6) — `Books.contentHash TEXT` stĺpec

### Mimo M3 (presunuté)

| Funkcia | Cieľ |
|---------|------|
| 3 témy (Svetlá, Sépia, Tmavá) + slider jasu | M3.5 |
| 4 zabalené fonty + výber fontu + veľkosť + riadkovanie | M3.5 |
| Settings panel z reader (ozubené koliesko) | M3.5 |
| Pagination mode + prepínanie scroll ↔ pagination | M4 |
| TOC navigácia | M5 |
| Záložky | M5 |
| Vyhľadávanie v knihe | M5 |
| Highlight tvorba | Fáza 3 |
| Multi-window / multi-book | nikdy v MVP |

---

## 4. Architektúra

### Vrstvy

```
ReaderScreen (UI, ConsumerWidget)
   │
   ├──> ReaderProviders (Riverpod)
   │     ├── currentReadingBookProvider     — aktuálne otvorená kniha
   │     ├── readingPositionProvider        — stream aktuálnej pozície
   │     └── darkModeProvider              — bool, persists cez SettingsKvDao
   │
   ├──> PositionPersister                  — debounced save → DAO
   │     └── debounce 1.5 s + immediate flush on dispose / route pop
   │
   ├──> PositionResolver                   — Plán A or B (M3 GATE)
   │     ├── computeAnchor(scrollState) → ReadingPositionAnchor
   │     └── resolveAnchorToScroll(anchor) → controller scroll action
   │
   ├──> ReadingPositionsDao                — wraps Drift ReadingPositions
   │     ├── insertOrUpdate(bookId, anchorJson)
   │     ├── getByBookId(bookId) → ReadingPositionAnchor?
   │     └── watchByBookId(bookId) → Stream
   │
   └──> EpubView (renderer)                — z M1 ADR 0001
```

### Dátový tok pri otvorení knihy

```
1. User klikne knihu → Navigator.pushNamed('/reader', arg: bookId)
2. ReaderScreen.initState:
   - load EpubBook (existing AddBookUseCase má parsovanie, reuse alebo nový reader-specific use case)
   - load ReadingPositionAnchor cez ReadingPositionsDao
   - inicializuj EpubController (epub_view) s loaded book
3. Po `loadingState == success`:
   - ak anchor existuje → PositionResolver.resolveAnchorToScroll(anchor)
   - inak začni od top (charOffset 0)
4. Render EpubView
```

### Dátový tok pri scroll-e

```
1. EpubController.currentValueListenable triggeruje
2. Listener → PositionResolver.computeAnchor(currentValue) → ReadingPositionAnchor
3. Anchor odovzdaný do PositionPersister
4. Persister debounce-uje 1.5 s, potom write cez ReadingPositionsDao
5. Pri dispose / back → immediate flush (force save bez čakania)
```

### Dátový tok pre dark mode

```
1. User klikne toggle v top bar
2. ref.read(darkModeProvider.notifier).toggle()
3. Notifier write cez SettingsKvDao: setString('darkMode', 'true'/'false')
4. MaterialApp theme rebuilds (riadené cez darkModeProvider watch v EpubReaderApp)
```

---

## 5. Plán A vs Plán B — GATE v Task 1

### Plán A — priame char→paragraph→scroll mapping

**Pri otvorení knihy:**
1. Pre každú kapitolu v spine vypočítaj `paragraphCharStarts: List<int>`
   (kumulatívne char positions kde každý paragraph začína v `CanonicalChapterText`).
2. Cache toto v memóri (alebo prepočítaj on-the-fly pri resolve).

**Resolve `(chapterId, charOffset)` → scroll position:**
1. Nájdi `paragraphCharStarts` pre danú kapitolu.
2. `paragraphIndexInChapter = upper_bound(starts, charOffset) - 1` (najbližší preceding paragraph start).
3. `absoluteParagraphIndex = chapterStartIndex + paragraphIndexInChapter`
   (`chapterStartIndex` z `EpubController.tableOfContents` — toto epub_view vystavuje).
4. `controller.scrollTo(index: absoluteParagraphIndex)`.

**Pre/proti:**
- ✅ Priama cesta, deterministická
- ✅ Nepotrebuje text search
- ⚠️ Závisí od epub_view paragraph-decomposition algoritmu (musí byť identický s naším)
- ⚠️ Mapping na `EpubController.scrollTo` paragraphs môže mať off-by-one alebo iné drobnosti

**Compute anchor (opačný smer):**
1. Z `currentValue.chapterNumber + paragraphNumber` získaj canonical text kapitoly
2. Sčítaj char dĺžky paragraphov [0..paragraphNumber)
3. To je `charOffset`

### Plán B — degenerated highlight cez findHighlight

**Compute anchor pri scroll:**
1. Z aktuálnej top-of-viewport pozície vezmi prvých ~80 znakov ako quote
2. Vytvor `HighlightAnchor` cez `AnchorCodec.createHighlight`
3. Z neho extrahuj `chapterId + charOffset` ako `ReadingPositionAnchor`
   (`chapterLength` z canonical text)

**Resolve:**
1. Vytvor synthetic `HighlightAnchor` z `ReadingPositionAnchor` + dorátaný quote
2. `AnchorCodec.findHighlight(anchor, book)` → `AnchorRange`
3. Mapuj `range.start` → paragraph cez ten istý algoritmus ako A (alebo cez text search v paragraphoch)
4. `controller.scrollTo(index: paragraphIndex)`

**Pre/proti:**
- ✅ Reuse-uje overený `AnchorCodec` z M2.5
- ⚠️ Potrebuje quote v `ReadingPositionAnchor` → buď uložiť navyše, alebo dorátať z chapter text pri resolve
- ⚠️ Pomalšie (text search)
- ✅ Robustnejšie pri zmene fontu / page split — quote sa nájde
- ✅ Funguje aj keď epub_view paragraph index sa správa nečakane

### GATE test (T1)

Pre rozhodnutie:

1. Implementuj Plán A v `lib/spike/reader_position/` (throwaway).
2. Spike screen: otvor `alice.epub`, manuálne scrollni na 3-5 pozícií, ulož snapshot
   `(chapterIndex, paragraphIndex, charOffset)`, zatvor, otvor znova, klikni „Resume",
   over že scroll skončil na očakávanom paragraph (±1).
3. Ak Plán A funguje na všetkých 4 fixtures (alice, pride, frankenstein, divina) →
   Plán A vyhráva.
4. Ak A zlyhá (off-by-line, nezhoda paragraph countu, …) → implementuj Plán B,
   znova testuj.
5. Výsledok v ADR 0005.

**Spike sa po T1 zmaže** (rovnako ako S0 spike v M2.5 — patternu sme verní).

---

## 6. Dátový model — zmeny v `reading_positions` tabuľke

Aktuálna schéma (M2):

```dart
class ReadingPositions extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  RealColumn get progressInChapter => real()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {bookId};
}
```

**M3 mení na:**

```dart
class ReadingPositions extends Table {
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get anchorJson => text()();          // ReadingPositionAnchor.toJson() ako string
  IntColumn get schemeVersion => integer().withDefault(const Constant(1))();  // BookIdentity scheme; pre future migration
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {bookId};
}
```

**Migration:** Drift `MigrationStrategy` — `schemaVersion: 1 → 2`, drop old columns
chapterIndex/progressInChapter, add `anchorJson` (nullable initially? alebo not-null
s pre-fill?). Keďže žiadne reading positions ešte neexistujú v praxi (M2 stub Reader
neuložil žiadne), môžeme spraviť hard drop + recreate. Toto sa zafixuje v Task 2.

### `Books.contentHash` (M2.6 integrácia)

Books tabuľka dostane:
```dart
TextColumn get contentHash => text().nullable()();          // BookIdentity.compute výsledok
IntColumn get identitySchemeVersion => integer().nullable()();  // pre future BookIdentity scheme bump
```

Pri otvorení knihy v reader screen, ak `contentHash == null`, dorátame a uložíme.
Backfill pre existujúce knihy on-demand, nie batch.

---

## 7. UI špecifikácia

### ReaderScreen layout

```
┌────────────────────────────────────────────────┐
│  ←  Title of Book                    🌙   ⋮   │  ← top bar (toggle)
├────────────────────────────────────────────────┤
│                                                │
│         Chapter text rendrované cez            │
│         EpubView…                              │  ← reader body (full screen ak chrome skrytý)
│                                                │
│                                                │
├────────────────────────────────────────────────┤
│  ▓▓▓▓▓░░░░░░░  42 %                            │  ← bottom bar (toggle)
└────────────────────────────────────────────────┘
```

- **Top bar:** back arrow (← back to library), book title (truncated), dark mode toggle (🌙 ↔ ☀️), overflow menu (zatiaľ disabled / „Coming in M3.5")
- **Bottom bar:** progress bar + % (z `EpubChapterViewValue.progress` × spine position vs total spine items)
- **Tap kdekoľvek v reader body:** toggle chrome (default skrytý pri vstupe)
- **Wake-lock počas readeru aktívny** (na mobile; PC ignoruje)

### Dark mode

- **Light:** background `#FFFFFF`, text `#1A1A1A` (defaults z epub_view, žiadny custom CSS)
- **Dark:** background `#1E1E1E`, text `#E0E0E0`
- Toggle ovplyvní celú appku (nielen reader) — `MaterialApp.themeMode`
- Persists cez `SettingsKvDao.setString('darkMode', 'true'|'false')`
- Default: `false` (light) pri prvom spustení

---

## 8. Riziká a otvorené otázky

### R1 — Plán A vs B (T1 GATE)
Najdôležitejšie. Riešené spike-om. Ak ani jeden nefunguje, M3 STOP a re-spec.

### R2 — `EpubController.scrollTo(index)` poradie
`epub_view` controller scrolluje na **absolute paragraph index** naprieč všetkými
kapitolami. Mapping `(chapterNumber, paragraphInChapter)` → absolute musí byť
deterministický. `tableOfContents()` vystavuje `EpubViewChapter.startIndex` —
otázka či to je presný start paragraph index alebo niečo iné. **T1 spike to overí.**

### R3 — Wake-lock dependency
Mobile needs wake-lock plugin (`wakelock_plus` alebo podobné). Pridať dep alebo
defer to M3.5? **Návrh: pridať teraz** — bez wake-lock je čítanie na mobile
frustrujúce (obrazovka po 30 s zhasne).

### R4 — Pagination v M4 môže redesign-núť `PositionResolver`
Pagination mode má vlastnú scroll mechaniku (snap na stranu). `PositionResolver`
musí byť interface ktorý M4 môže reimplementovať. **M3 návrh:** `abstract class
PositionResolver` + `ScrollModeResolver` impl. M4 pridá `PaginatedModeResolver`.

### R5 — Resume tolerance ±1 paragraph
Akceptujeme. User očakáva „pokračujem kde som skončil" čo nie je presný byte.
Test: ulož na paragraph N, resume na paragraph N (test) alebo paragraph N±1
(akceptovateľné).

### R6 — Books.contentHash backfill
Existujúce knihy v DB nemajú hash. **Návrh:** pri otvorení knihy v readeri, ak
`book.contentHash == null`, dorátame `BookIdentity.compute` a uložíme. Lazy
backfill, nie batch migration. To je jednoduchšie a nemá failure mode batchu.

---

## 9. Akceptačné kritériá (DoD)

- [ ] T1 GATE: Plán A alebo B funguje pre všetky 4 fixtures (alice, pride, frankenstein, divina) — manuálny test 3-5 pozícií per fixture
- [ ] ADR 0005 napísaný s rozhodnutím
- [ ] `flutter analyze` clean
- [ ] `flutter test` pass (vrátane nových `PositionResolver`, `PositionPersister`, `ReadingPositionsDao` testov)
- [ ] `flutter build windows --debug` builds
- [ ] Manuálny e2e na Windows:
  1. Otvor `alice.epub` z knižnice
  2. Scrollni na ~50% knihy
  3. Zatvor reader (back arrow alebo OS close)
  4. Znovu otvor tú istú knihu
  5. ✅ Resume na ±1 paragraph od uloženej pozície
  6. Toggle dark mode → text + background sa zmení
  7. Reštart appky → dark mode preferencia perzistuje
  8. Tap chrome → toggle visible
- [ ] Spike `lib/spike/reader_position/` zmazaný po T1
- [ ] Branch `m3-reader-v1` mergnuteľný do master (fast-forward)

---

## 10. Mileniky (predbežné, T1 môže zmeniť)

| ID | Cieľ | Pozn. |
|----|------|-------|
| **T1** | **GATE: Plán A vs B spike** + ADR 0005 | Spike-first |
| T2 | DB migration: `reading_positions` schema v2 + `Books.contentHash` | Drift `MigrationStrategy` |
| T3 | `ReadingPositionsDao` + tests | In-memory DB |
| T4 | `PositionResolver` interface + ScrollModeResolver impl + tests | Per ADR 0005 |
| T5 | `PositionPersister` (debounce 1.5 s) + tests | Mock DAO |
| T6 | `ReaderScreen` skeleton — open + render | Replaces ReaderStubScreen |
| T7 | Wire scroll listener → persister; resume flow on open | Integration test |
| T8 | Reader chrome (top/bottom bar + tap-toggle) | Widget test |
| T9 | Dark mode toggle + `SettingsKvDao` persistence + theme wiring | Provider rebuild |
| T10 | Books.contentHash lazy backfill on first open | |
| T11 | Manual e2e + ADR finalizácia + spike cleanup | DoD |

Detailný plán cez `superpowers:writing-plans` po schválení tohto spec-u.

---

## 11. Schvaľovanie

- [ ] Používateľ prečítal spec
- [ ] Pripomienky zapracované
- [ ] Spec schválený → implementačný plán cez `writing-plans` skill
