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

- ✅ Resume na správnej pozícii (scripted 3-5 pozícií)
- ✅ **Resume correctness v organickom dennom čítaní** — sedel celý týždeň reálneho
  čítania, aj po dlhých session-och, aj mid-chapter, aj cez cold restart?
  (Scripted run odhalí hrubé chyby; organické čítanie odhalí drift, race conditions,
  edge cases ktoré sa neopakujú deterministicky.)
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
   │     └── debounce 1.5 s
   │     └── immediate flush on: dispose, route pop, AppLifecycleState.paused
   │       (Mobile OS môže zabiť appku bez dispose — paused je posledný spoľahlivý
   │        hook pred kill-om. Cez WidgetsBindingObserver.)
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

## 5. Plán A vs Plán B — GATE v Task 1 (REVISED)

### Jadrová tenzia, ktorá definuje M3

Tu je vec ktorú treba explicitne pomenovať lebo je centrálna, nie okrajová:

- **`epub_view` natívny paragraph index** by dal trivílny self-konzistentný resume,
  ale je **render/library-dependent** — rozbil by celý render-agnostický anchor
  formát (cross-device portability).
- **Char-offset v canonical texte** je **prenosný** medzi zariadeniami, ale
  potrebuje mapping na epub_view paragraph index aby sa scrollni-lo.

To napätie je jadro M3, nie edge case R2. **Dôsledok ktorý spec explicitne priznáva:**
dosiahnuteľná presnosť resume v M3 je **paragraph-level** — `epub_view`
pri scroll-e reportuje granularitu odseku, nie znak. `±1 paragraph` tolerancia
nie je ústupok, je to fyzický limit rendereru. **`charOffset` nevyzerá presnejšie
než reálne je** — jeho hodnota je v prenosnosti na iné zariadenie, nie v presnosti
na tomto. Toto je dôležitý mental model pre M3.5 a Fázu 5.

### Prečo Plán A „ako napísaný" pravdepodobne nie je implementovateľný

`CanonicalChapterText` (M2.5) bol postavený pre **char-level text matching**,
nie pre paragraph segmentation. Konkrétne:

- `CanonicalChapterText._normalize` kolabuje **všetok whitespace** na jednu medzeru
  (zhodne s M2.6 `_identityNormalize`). To znamená že v canonical texte **nie sú
  hranice odsekov** — `paragraphCharStarts` z neho **nemá z čoho vzniknúť**.
- Aj keby sme mali paragraph hranice z iného zdroja (parsovaním raw HTML),
  `epub_view` rozsekáva kapitolu na **blok-úrovňové elementy cez `flutter_html`**
  (`<p>`, `<div>`, `<h1-h6>`, `<blockquote>`, `<li>`, `<img>` ako samostatné
  „odseky"). Náš vlastný paragraph count by sa s ním nemusel kryť off-by-N.

Takže Plán A v pôvodnom znení (paragraphCharStarts z CanonicalChapterText)
**nefunguje**. Ak by sme chceli A, museli by sme parsovať raw HTML zhodne s
flutter_html (zložité, krehké).

### GATE redesign — measurement first, expect B

**Nerob sekvenčne „postav A, ak padne skús B" — pomalé.** Prvý krok spike-u je
**meranie** ktoré rozhodne za pár minút, nie dni:

#### Step 0 — Dva probe-y na rozhodnutie GATE (kritické)

Plán B tvrdí že „obchádza zarovnanie indexov" — ale **iba ak vieme prečítať text
odseku epub_view podľa jeho indexu cez public API**. Bez tej čitateľnosti by
sa Plán B ticho zrútil späť do požiadavky Plánu A (vlastná segmentácia musí
byť zarovnaná s epub_view). Step 0 preto meria **dve** veci, nie jednu.

##### Probe 1 — Čitateľnosť textu odseku epub_view cez API (PRIMÁRNY make-or-break)

Spike screen pre alice.epub:
1. Otvor knihu cez `EpubController`, počkaj na `loadingState == success`
2. Pokús sa cez **public API** dostať k textu odseku N v aktuálnej kapitole:
   - Skús `EpubController.currentValue?.chapter` → `EpubChapter.HtmlContent` (raw HTML)
   - Skús či `epub_view` má vystavené `Paragraph` objekty cez nejaký getter
   - Skús `controller.tableOfContents()` či vystavuje paragraph-level info
   - Skús reverse-engineering cez internal state (ak je `_epubViewState` viditeľné — pravdepodobne nie)
3. **Verdict:** dostali sme sa k stringu textu konkrétneho odseku cez public API?

##### Probe 2 — Paragraph alignment (sekundárny, len ak Probe 1 padol)

Pre každú kapitolu (alice na začiatok stačí, divina pre stress):
1. **Z epub_view strany:** scrollni cez celú kapitolu, zaznamenaj posledné
   `currentValue.paragraphNumber` (= počet odsekov v kapitole podľa epub_view).
2. **Z našej strany:** parsuj raw HTML z `book.Content.Html`, počítaj block-level
   elementy zhodne s tým ako by ich segmentoval flutter_html
   (`<p>`, `<div>`, `<h*>`, `<blockquote>`, `<li>`, `<img>`).
3. **Porovnaj** počty (a stratifikuj — koľko fixtures sa kryje, kde sú off).

##### Rozhodovací strom

**Vetva 1 — Probe 1 ✅ (text odseku čitateľný cez API):**
- **Plán B funguje alignment-free.** Hľadáme quote v skutočných epub_view
  odsekoch, index je priamo použiteľný v `scrollTo`. Najlepší prípad.
- Probe 2 sa nemusí robiť (alignment je irelevantný).
- ADR 0005 dokumentuje: Plán B-pure, API metóda použitá na získanie textu.

**Vetva 2 — Probe 1 ❌, Probe 2 ✅ (alignment sa kryje):**
- Plán B cez **vlastné parsovanie + alignment-dependent mapping**. Funguje,
  ale je krehkejšie — závisí od trvalej zhody našej HTML segmentácie s
  flutter_html. Akýkoľvek upgrade `flutter_html` môže túto zhodu rozbiť.
- ADR 0005 explicitne dokumentuje túto krehkosť ako known risk a pripne
  `flutter_html` verziu prísnejšie (per M2.6 html package precedent).
- Pridáme test ktorý alignment kontroluje na fixtures (regression guard).

**Vetva 3 — Probe 1 ❌, Probe 2 ❌ (ani text, ani alignment):**
- **Ani jeden plán nefunguje.** Toto je renderer wall na ktorú strategy doc
  upozorňovala. R1 „M3 STOP a re-spec" je reálne na stole.
- Otvára sa otázka **návratu k WebView rendereru** (`flutter_epub_viewer` s
  opraveným Windows crashom z M1), alebo iného rendereru.
- **Toto je strategické rozhodnutie ktoré sa NEROBÍ ticho v M3 spike-u.**
  Ak sa Vetva 3 stane, M3 sa zastaví, výsledok Step 0 sa pošle na review
  spolu s návrhom ďalšieho postupu, a rozhodnutie sa robí spoločne (nie
  pretlačením náhradného plánu).

##### Bonus, ak ostane čas

Aj v Vetve 1 a 2 stojí za to skontrolovať či `scrollTo(index)` reálne pristane
na očakávaný odsek cez 3-5 manuálnych pozícií na alice.epub. To overí timing
(postFrameCallback potreba) ešte pred T2+. Lacné a šetrí debug v ostatných taskoch.

Toto Step 0 celé je **pol dňa práce maximum**. Bez stavby reálneho resolveru,
bez DB integrácie.

#### Step 1 — Plán B (očakávaná cesta)

Plán B vyhráva nielen ako útecha — **obchádza celý problém zarovnania indexov**.
Text search nájde quote a potom zistíme ktorý epub_view odsek ten text obsahuje.
**Nepotrebuje aby sa paragraph modely kryli.** To je presne dôvod prečo je
robustný.

**Compute anchor pri scroll:**
1. Z `currentValue.chapter` získaj `chapterId` (manifest href / `#<index>`)
2. Z `currentValue.paragraphNumber` získaj **text aktuálneho top paragraph-u**
   (z epub_view internal chapter structure — `epub_view` ich má naparsované)
3. Vezmi prvých ~80 znakov tohto textu po normalizácii → `quote`
4. Vyhľadaj `quote` v `CanonicalChapterText.extract(book, chapterId)` →
   `charOffset` v canonical
5. Ulož `ReadingPositionAnchor(chapterId, charOffset, chapterLength)` +
   transient `quote` pole (in-memory, pre rýchly resolve bez prepočtu)

**Resolve:**
1. Z uloženého anchoru: vezmi `chapterId + charOffset` → CanonicalChapterText
2. Z canonical extrahuj ~80-znakový quote okolo `charOffset` (alebo použi
   pamätaný transient quote ak je k dispozícii)
3. Iteruj epub_view paragraphs v danej kapitole, nájdi prvý ktorého
   normalizovaný text **obsahuje quote** (alebo má najlepší fuzzy match)
4. `controller.scrollTo(index: absoluteParagraphIndex)`

#### Step 2 — Validate Plán B na COLD restart

**Spike e2e (per fixture):**
1. Spike screen pre alice.epub
2. Scrollni na 5 pozícií, pre každú zachyť anchor
3. **Zavri appku úplne (`flutter run` Ctrl+C, alebo OS kill cez task manager)**
4. **Znovu spusti** appku (cold start, nie hot reload)
5. Otvor anchor probe, klikni „Resume to position N"
6. Over že scroll skončil na očakávanej pozícii (±1 paragraph)

Cold restart je kritické lebo:
- `scrollTo(index)` hneď po `loadingState == success` môže pristáť zle —
  scroll view ešte nezmeral extent
- Riešenie typicky cez `WidgetsBinding.addPostFrameCallback` alebo malý retry
- Toto je presne ten typ veci čo v spike-u chceš vidieť kým je throwaway

### GATE deliverables (T1)

- **Probe 1 výsledok**: čitateľnosť textu odseku epub_view cez API (Yes/No + dôkaz)
- **Probe 2 výsledok** (ak Probe 1 padol): paragraph alignment tabuľka per fixture
- Vetva (1/2/3) a podľa nej:
  - **Vetva 1 alebo 2:** Implementácia Plán B v zvolenom režime
  - **Vetva 3:** STOP, návrh na strategický review (žiadna ďalšia implementácia)
- ADR 0005 dokumentujúce probe výsledky + voľbu + (ak Vetva 1/2) cold restart timing finding
- Spike `lib/spike/reader_position/` sa po dokončení zmaže (M2.5 pattern)

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
  TextColumn get anchorJson => text()();          // ReadingPositionAnchor.toJson() — NOT NULL
  IntColumn get schemeVersion => integer().withDefault(const Constant(1))();  // BookIdentity scheme; pre future migration
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {bookId};
}
```

**Migration:** Drift `MigrationStrategy` — `schemaVersion: 1 → 2`, drop old columns
chapterIndex/progressInChapter, add `anchorJson` (**NOT NULL**). Keďže žiadne
reading positions ešte neexistujú v praxi (M2 stub Reader neuložil žiadne),
robíme **hard drop + recreate**.

**Konvencia: žiadne null-anchor riadky.** Riadok v tabuľke vznikne **až pri
prvom save**. `getByBookId(...) == null` znamená „kniha ešte nebola otvorená /
nemá uloženú pozíciu" → reader začne **od vrchu**. Tým pádom `anchorJson` môže
byť `NOT NULL` bez kompromisu.

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
- **Bottom bar:** progress bar + % (z `EpubChapterViewValue.progress` × spine position vs total spine items).
  Pozn.: **toto % je render-based** (aktuálna scroll pozícia v aktuálnej kapitole
  váhovaná pozíciou v spine) — je **približné** a render-závislé. Slúži len ako
  kozmetika v bottom bare. **NEzamieňať s `ReadingPositionAnchor.progress`** ktorý
  je char-based a deterministický pre sync účely. Dve rôzne čísla, dva rôzne účely.
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
  3. Zatvor reader (back arrow)
  4. Znovu otvor tú istú knihu (within-session reopen)
  5. ✅ Resume na ±1 paragraph od uloženej pozície
  6. Toggle dark mode → text + background sa zmení
  7. Reštart appky → dark mode preferencia perzistuje
  8. Tap chrome → toggle visible
- [ ] **Manuálny e2e — COLD restart** (kritický, layout timing test):
  1. Otvor knihu, scrollni na ~50%
  2. **Úplne zabi appku** (Task Manager kill na Windows, alebo `flutter run` Ctrl+C)
  3. **Studeno spusti appku znova** (nie hot reload)
  4. Otvor tú istú knihu
  5. ✅ Resume na ±1 paragraph (môže potrebovať postFrameCallback / retry — spike to vyrieši)
- [ ] **Lifecycle flush test (Android emulator alebo manual)**:
  1. Otvor knihu, scrollni
  2. V rámci debounce okna (1.5 s) → swipe appku z recents alebo OS kill
  3. Spusti znova, otvor knihu
  4. ✅ Pozícia uložená (paused hook flushol pred kill-om)
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
