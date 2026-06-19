# Fáza 1 — MVP „Čítačka" (Spec)

**Status:** Draft (čaká na review používateľa)
**Dátum:** 2026-06-20
**Predchádza:** žiadna fáza (toto je prvá)
**Nasleduje:** Fáza 2 — Navigácia v knihe

---

## 1. Cieľ

Postaviť najmenšiu zmysluplnú verziu EPUB čítačky, ktorá:

1. beží na **Windows** a **Android** z jedného Flutter codebase-u,
2. spoľahlivo otvorí a zobrazí bežný EPUB súbor,
3. zapamätá si rozčítané knihy a pozíciu,
4. ponúka pohodlie čítania (téma, font, veľkosť, dva čítacie režimy),
5. má architektúru pripravenú na ďalšie fázy (i18n, DB, plugin-friendly cloud, anotácie…).

Príbeh používateľa pre MVP:

> *„Stiahnem si appku. Pridám priečinok s EPUB knihami. V knižnici si nájdem rozčítaný titul, otvorím ho a čítam. Keď zatvorím appku a otvorím ju znova, sedím tam, kde som skončil. Pre nočné čítanie si prehodím tému na tmavú a stlmím jas."*

---

## 2. Mimo rozsah (presunuté do neskorších fáz)

| Funkcia | Fáza |
|--------|------|
| TOC navigácia, záložky, vyhľadávanie v knihe, indikátor pokroku v kapitole | Fáza 2 |
| Zvýrazňovanie textu, poznámky | Fáza 3 |
| Tagy, kolekcie, hodnotenia, manuálna úprava metadát, online vyhľadanie obálok | Fáza 4 |
| Cloud sync (Google Drive / OneDrive / WebDAV / …) | Fáza 5 |
| Slovník, štatistiky čítania, plne vlastné farby, vlastné `.ttf` fonty, dyslexické fonty | Fáza 6 |

Tieto veci v MVP NIE SÚ — ani v skrytej forme, ani v zakázanom UI. Architektúra ich však nesmie znemožniť.

---

## 3. Cieľové platformy a stack

### Platformy
- **Windows 10/11** (desktop)
- **Android** (telefón aj tablet, minimum API 24 / Android 7.0)

iOS, macOS, Linux nie sú cieľom MVP, ale ničím v dizajne ich do budúcna nevylúčime.

### Stack
- **Flutter 3.x + Dart 3.x**
- **Riverpod** (v2+) — state management
- **Drift** (na SQLite) — lokálna databáza
- **`go_router`** — navigácia
- **`flutter_localizations` + ARB** — i18n (MVP shipne so slovenčinou)
- **EPUB rendering:** rozhoduje sa v Mileniku M1 (viď §9). Kandidáti:
  - `flutter_epub_viewer` (wrapper okolo `epub.js` cez WebView) — najzrelší rendering,
  - `epub_view` — natívny Flutter widget,
  - `epubx` + vlastný HTML renderer (`flutter_html` alebo custom) — najviac kontroly.
- **`file_picker`**, **`desktop_drop`** (Windows drag&drop), **`path_provider`**.

> Verzie balíčkov sa zafixujú v `pubspec.yaml` v M1.

---

## 4. Architektúra (vysoká úroveň)

### Vrstvy

```
┌──────────────────────────────────────────────────────┐
│ UI vrstva (Flutter widgets, GoRouter routes)          │
│  - HomeScreen, LibraryScreen, ReaderScreen, Settings │
├──────────────────────────────────────────────────────┤
│ State (Riverpod providers / notifiers)                │
│  - LibraryController, ReaderController, ThemeNotifier │
├──────────────────────────────────────────────────────┤
│ Domain (čisté Dart triedy, žiadne Flutter importy)    │
│  - Book, ReadingPosition, LibrarySource, Theme        │
├──────────────────────────────────────────────────────┤
│ Data                                                  │
│  - Drift DB (BooksDao, PositionsDao, SettingsDao)     │
│  - FileSystemRepo (kopírovanie/skenovanie EPUB)       │
│  - EpubParser (metadata + obálka)                     │
│  - EpubRenderer (vykreslenie obsahu — abstrakcia)     │
└──────────────────────────────────────────────────────┘
```

Pravidlá:

- **Domain nikdy neimportuje Flutter ani Drift.** Je to čistý Dart, testovateľný unit testami bez emulátora.
- **UI nikdy nesiaha priamo do databázy ani filesystému.** Vždy cez Riverpod providery.
- **`EpubRenderer` je rozhranie** s implementáciou závislou od zvolenej knižnice → meniteľné v M1 bez prepisovania UI.

### Mapa hlavných obrazoviek

```
/
├─ /home              (Domov: Pokračovať, Naposledy pridané, Knižnica)
├─ /library           (samostatný pohľad na celú knižnicu, grid/list toggle)
├─ /reader/:bookId    (čítací režim)
└─ /settings
   ├─ /settings/library     (spravovaná vs sledované priečinky)
   ├─ /settings/appearance  (téma, jas, font, veľkosť, riadkovanie, okraje)
   ├─ /settings/reading     (pagination vs scroll, „po spustení otvor")
   └─ /settings/advanced    (povoliť systémové fonty)
```

---

## 5. Moduly / komponenty

### 5.1 Knižnica (Library)

**Zodpovednosť:** evidencia kníh a ich umiestnenia na disku.

**Režimy úložiska** (prepínateľné v `/settings/library`):

- **Managed (default)** — appka kopíruje EPUB do `${ApplicationDocumentsDir}/EpubReader/Books/`. Súbor v knižnici je `<bookId>.epub`. Pôvodný súbor sa nedotkne.
- **Watched folders** — používateľ pridá zoznam ciest. Appka pravidelne (a manuálne tlačidlom) skenuje, hľadá `*.epub`, eviduje cesty. **Nič nekopíruje.**

Oba režimy môžu existovať súčasne — jednu knihu „spravujem", druhú „len sledujem".

**Pridanie knihy:**
- `+ Pridať knihu` → `file_picker.pickFiles(allowedExtensions: ['epub'], allowMultiple: true)`,
- `+ Pridať priečinok` → `file_picker.getDirectoryPath()` → skenuje rekurzívne,
- **Drag & drop** (len Windows) → `desktop_drop` package, prijíma `.epub`.

Pri pridaní:
1. spustí sa `EpubParser` → extrahuje sa `title`, `author`, `language`, `coverImage` (z OPF),
2. vytvorí sa `Book` záznam v DB,
3. obálka sa uloží ako `${ApplicationSupportDir}/EpubReader/covers/<bookId>.png` (pre rýchle načítanie do grid-u, nezávisle od toho, či je kniha managed alebo watched).

**Chyby a okrajové prípady:**
- Súbor nie je validný EPUB → toast „Nepodarilo sa otvoriť: ${meno}", do logu detail, kniha sa NEPRIDÁ.
- Duplicita (rovnaký `title + author`) → dialog „Kniha už existuje. Pridať ako duplikát / Preskočiť".
- DRM-chránený EPUB (Adobe ADEPT) → toast „Tento súbor je chránený DRM, nevieme ho otvoriť", kniha sa NEPRIDÁ. Detekuje sa cez `META-INF/rights.xml` v ZIP-e.

### 5.2 Domov (Home)

Tri sekcie pod sebou (alebo carousely):

- **Pokračovať v čítaní** — knihy s `lastReadAt != null`, zoradené DESC, max 6.
- **Naposledy pridané** — zoradené podľa `addedAt` DESC, max 6.
- **Knižnica** — link/tlačidlo „Otvoriť knižnicu" + prvých 6 kníh.

Ak je knižnica prázdna, ukáže sa onboarding karta s tlačidlami `+ Pridať knihu / + Pridať priečinok`.

### 5.3 Knižnica — pohľad (LibraryScreen)

- **Prepínač Grid ↔ List** v hornej lište.
- **Grid:** obálka + názov pod ňou. Dlhý-stlač / right-click → kontextové menu (Otvoriť / Odstrániť z knižnice).
- **List:** miniatúra + názov + autor + pokrok %.
- Triedenie iba „Naposledy pridané" v MVP (ďalšie možnosti v Fáze 4).
- Filtrovanie iba textový search podľa názvu/autora.

### 5.4 Čítací režim (ReaderScreen)

**Vrstvenie:**

```
┌──────────────────────────────────────────┐
│  ◂ Knižnica       Názov knihy        ⚙   │ ← horná lišta (toggle)
├──────────────────────────────────────────┤
│                                          │
│         text textu textextov             │
│         textext textextov textex         │   ← samotná stránka / scroll
│         textex textextov text            │
│                                          │
├──────────────────────────────────────────┤
│  43%  ━━━━━━━━━━━━━●─────────  4h 12m   │ ← dolná lišta (toggle)
└──────────────────────────────────────────┘
```

**Interakcie:**
- **Stránkovanie:** swipe vľavo/vpravo (mobil), klik na ľavú/pravú tretinu obrazovky, alebo šípky ←/→ (PC).
- **Scrollovanie:** swipe hore/dole (mobil), koliesko myši / Page Up/Down / Space (PC).
- **Klepnutie na stred** → toggle líšt.
- Lišty sa hneď po vstupe do readeru predvolene **skryjú** (čistý text).

**Pozícia čítania:**
- Ukladá sa **po každej zmene strany / debounced 1.5 s pri scrolle**.
- Granularita: `chapterIndex` + `progressInChapter` (0.0 – 1.0). Bez znalosti vykreslenej výšky neukladáme stranu ako absolútne číslo.
- Pri otvorení knihy sa pozícia obnoví na rovnaký bod, **aj keď používateľ medzitým zmenil veľkosť písma alebo režim pagination↔scroll** (prepočet z `progressInChapter`).

**Nastavenia z readera** (ozubeným kolieskom v hornej lište):
- téma (svetlá/sépia/tmavá) + slider jas,
- font (zoznam),
- veľkosť písma (± / slider),
- riadkovanie (1.2 / 1.4 / 1.6 / 1.8),
- okraje (úzke / stredné / široké),
- pagination ↔ scroll.

### 5.5 Vzhľad a témy

**Tri pevné témy:**

| Téma | Pozadie | Text | Lišty |
|------|---------|------|-------|
| Svetlá | `#FFFFFF` | `#1A1A1A` | systémový bar |
| Sépia | `#F4ECD8` | `#5B4636` | tlmený béžový |
| Tmavá | `#1E1E1E` | `#E0E0E0` | tmavý bar |

**Slider jasu** — upravuje `value` (HSL) pozadia v rozsahu ±15 % a synchronne dotype textu, aby kontrast zostal čitateľný.

**Fonty:**
- 4 zabalené do appky (presný výber sa zafixuje v M2 — kandidáti: Source Serif 4, EB Garamond, Atkinson Hyperlegible, Inter / Open Sans).
- **„Povoliť systémové fonty"** v Pokročilých nastaveniach → appka načíta dostupné fonty cez `flutter_font_picker` (alebo platformovo).

### 5.6 Nastavenia (Settings)

Štyri stránky (viď §4 mapu):

- **Knižnica** — režim úložiska, zoznam sledovaných priečinkov, tlačidlo „Skenovať teraz".
- **Vzhľad** — téma, jas, font, veľkosť, riadkovanie, okraje. *Tieto nastavenia sú aplikované globálne; v Reader-i sú duplicitné prístupné aj ozubeným kolieskom.*
- **Čítanie** — pagination vs scroll, „Po spustení otvor: Domov / Knižnica / Posledná kniha".
- **Pokročilé** — povoliť systémové fonty, vymazať cache obálok, exportovať knižnicu (JSON), o aplikácii.

### 5.7 i18n

- `flutter_localizations` + `gen-l10n` z `.arb` súborov v `lib/l10n/`.
- V MVP existuje `app_sk.arb` (kompletný) a `app_en.arb` (kostra so slovenskými hodnotami ako fallback — pripravené pre neskoršie preklady).
- Žiadne hardcoded reťazce v UI; všetko cez `AppLocalizations.of(context).<key>`.

---

## 6. Dátový model

### Drift tabuľky

```dart
// books — záznam o jednej knihe v knižnici
class Books extends Table {
  TextColumn get id => text()();                        // UUID
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get filePath => text()();                  // absolútna cesta na disku
  TextColumn get storageMode => text()();               // 'managed' | 'watched'
  TextColumn get coverPath => text().nullable()();      // cesta k extrahovanej obálke
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
}

// reading_positions — kde som skončil v každej knihe
class ReadingPositions extends Table {
  TextColumn get bookId => text().references(Books, #id)();
  IntColumn get chapterIndex => integer()();
  RealColumn get progressInChapter => real()();         // 0.0 – 1.0
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {bookId};
}

// watched_folders — priečinky v režime „sledované"
class WatchedFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
}

// settings — kľúč → JSON hodnota
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get jsonValue => text()();
  @override Set<Column> get primaryKey => {key};
}
```

Položky v `settings`:
- `theme` → `{ "name": "sepia", "brightness": 0.0 }`
- `typography` → `{ "fontFamily": "Source Serif 4", "size": 18, "lineHeight": 1.4, "margins": "medium" }`
- `readingMode` → `"paginated" | "scroll"`
- `startupScreen` → `"home" | "library" | "lastBook"`
- `storageMode` → `"managed" | "watched" | "hybrid"`
- `allowSystemFonts` → `true | false`

---

## 7. Kľúčové používateľské toky

### 7.1 Prvé spustenie
1. Otvorí sa **Home** (default).
2. Knižnica je prázdna → onboarding karta.
3. Klik na `+ Pridať priečinok` → vyberie napr. `D:\Knihy\` → režim sa nastaví na **managed** (kópia) alebo **watched** podľa toho ktorú voľbu klikol v dialógu.
4. Beží import → progress bar (počet pridaných / celkový počet).
5. Po dokončení sa zobrazí Home s naplnenou sekciou „Naposledy pridané".

### 7.2 Otvorenie a čítanie
1. Z Home alebo Library klikne na knihu.
2. Otvorí sa **Reader**, načíta sa posledná pozícia (alebo začiatok ak je čerstvá kniha).
3. Klepne na stred → toggle lišty, klikne na ozubené koleso → upraví font.
4. Číta. Pozícia sa autosave-uje.
5. Zatvorí appku.

### 7.3 Návrat
- Podľa `startupScreen`:
  - **home** → Home s ňou v „Pokračovať v čítaní".
  - **library** → Knižnica.
  - **lastBook** → priamo Reader na danej pozícii.

### 7.4 Zmena vzhľadu
1. V Reader-i ozubené koliesko → bottom-sheet panel s nastaveniami vzhľadu.
2. Zmena sa **prejaví okamžite** (provider invalidácia).
3. Hodnoty sa uložia do DB, platia globálne pre všetky knihy.

---

## 8. UX poznámky

- **Žiadny telemeter, žiadne reklamy, žiadne „upgrade" hlášky.** Toto je pevný princíp celého projektu.
- **Žiadne registrácie ani prihlasovania v MVP.** (V Fáze 5 prihlasovanie do cloudu, ale aj tak voliteľné.)
- **Wake-lock počas čítania** (najmä na Androide) — obrazovka nezhasína. Vypne sa pri opustení readera. Voliteľné v Settings (default ON na mobile, N/A na PC).
- **Zachovaná veľkosť okna** na Windows medzi spusteniami.
- **Žiadne externé sieťové volania** v MVP. Všetko offline.

---

## 9. Riziká a otvorené otázky

### R1 — Výber EPUB renderera (najväčšie riziko MVP)
- **Problém:** kvalita renderingu v Dart-only knižniciach je nižšia než `epub.js` (JS). WebView wrapper (`flutter_epub_viewer`) dáva najlepší vizuál, ale má vlastné komplikácie (komunikácia s widgetom, performance na slabších Androidoch).
- **Mitigácia (Milenik M1):** spike — postavím minimálny prototyp s každým z troch kandidátov, otestujem na rovnakej sade 4 EPUB-ov (jeden jednoduchý, jeden s vlastným CSS a fontmi, jeden s veľa obrázkami, jeden v slovenčine s diakritikou). Vyberiem podľa výsledku. Rozhodnutie zafixujem do tohto spec-u ako ADR.
- **Krajný scenár:** ak žiaden nestačí, postavím vlastný renderer nad `epubx` + Flutter Web kompozícia → ale to by posunulo MVP o niekoľko týždňov.

### R2 — Pagination + scroll v jednej app-ke je 2× práca
- Reálna investícia. Akceptujeme ju vedome, je to požiadavka používateľa.
- **Zmierenie:** scroll implementujeme ako primárny mód (jednoduchší — celá kniha v jednom widgete + scroll controller), pagination ako derivát (rozdelíme content podľa výšky obrazovky a fontu). Z technického hľadiska to zjednoduší persistenciu pozície (oba módy zdieľajú `chapterIndex + progressInChapter`).

### R3 — Drag & drop na PC
- Funkčnosť závisí od `desktop_drop` package, ktorý ešte občas má rough hrany na Windows. **Otvorená otázka:** ak nebude fungovať spoľahlivo do konca MVP → zhodíme drag&drop a necháme len file picker a folder picker (pridáme do Fázy 6 keď dozrie ekosystém).

### R4 — DRM detekcia
- Nie všetky DRM-chránené EPUB-y majú `META-INF/rights.xml`. Niektoré sa zlomia až pri parsovaní obsahu. **Mitigácia:** pri zlyhaní parsera → friendly chyba „Súbor sa nepodarilo otvoriť. Môže byť poškodený alebo chránený DRM."

### R5 — Veľké knihy (500+ kapitol, 10+ MB)
- Načítanie do pamäte môže byť pomalé. **Mitigácia:** lazy parsing — pri otvorení čítame len OPF + aktuálnu kapitolu, ďalšie kapitoly podľa potreby.

### Otvorené otázky pre review
- **OQ1:** Pri pridaní priečinku — pýtame sa dialógom „managed alebo watched", alebo má každý priečinok atribút? *Návrh:* pri prvom pridaní pýtame, zapamätáme preferenciu do Settings, ďalšie pridávania sa už nepýtajú (mení sa v Settings).
- **OQ2:** Obnova okna na PC — máme zachovať aj poslednú otvorenú obrazovku? *Návrh:* nie, vždy ideme cez `startupScreen` Setting.
- **OQ3:** Mobile orientation lock v Reader-i? *Návrh:* default „follow system", v Reader-i bude bottom-sheet voľba „Zamknúť otáčanie". Považujem za MVP-okay; ak to budeš chcieť presunúť do Fázy 6, povedz.

---

## 10. Akceptačné kritériá (Definition of Done pre MVP)

MVP je hotový, ak na **Windows** aj **Android** je možné:

1. Pridať jednu konkrétnu knihu cez file picker.
2. Pridať priečinok s minimálne 20 knihami a v knižnici sa všetky zobrazia s obálkou (alebo placeholder-om).
3. Otvoriť knihu, prečítať aspoň 3 kapitoly, zatvoriť appku.
4. Po znovuotvorení sa pozícia obnoví ±1 odstavec.
5. Prepnúť tému, font, veľkosť písma — zmeny sa hneď prejavia a po reštarte ostanú.
6. Prepnúť medzi pagination a scroll bez pádu a so správnym prepočtom pozície.
7. Zobraziť aplikáciu kompletne v slovenčine, bez hardcoded textov.
8. Pridať DRM-chránený alebo poškodený súbor → vidieť čitateľnú chybovú hlášku, knižnica zostáva konzistentná.
9. Aplikácia neposiela žiadne sieťové volania (overiteľné network monitoring).
10. Zachovaná veľkosť okna na Windows medzi spusteniami.

---

## 11. Testovacia stratégia

- **Unit testy (Dart):** Domain vrstva — `EpubParser`, `ReadingPosition` prepočty, `LibraryController` logika. Cieľ ≥ 80 % coverage.
- **Integration testy:** Drift databáza — CRUD nad `Books`, `ReadingPositions`, `Settings`.
- **Widget testy:** kľúčové obrazovky (`HomeScreen`, `LibraryScreen`, `ReaderScreen`) — render, interakcie.
- **Manuálny test plán:** v `docs/specs/phase-1-mvp-testplan.md` (vznikne ako súčasť implementácie) — 10 akceptačných kritérií prevedené krok po kroku.
- **Testovacie EPUB súbory:** zložka `test/fixtures/` so 4 reálnymi knihami pokrývajúcimi rôznu zložitosť (jedna pôjde do repa z public-domain zdrojov, napr. Project Gutenberg).

---

## 12. Mileniky (predbežne)

| ID | Cieľ | Hotovo keď |
|----|------|------------|
| **M1** | Renderer spike + výber | 3 prototypy, porovnanie, rozhodnutie, aktualizovaný spec |
| **M2** | Library + DB + Settings backbone | Pridanie knihy, perzistencia, prázdny Reader stub |
| **M3** | Reader v1 — scroll mód | Otvorenie knihy, scroll, pozícia, témy, font |
| **M4** | Reader v2 — pagination | Stránkovanie, prepínanie módu, prepočet pozície |
| **M5** | Domov + Settings UI | Home so sekciami, Settings všetky 4 stránky |
| **M6** | i18n + leštenie + builds | Slovenský preklad, akceptačné kritériá splnené, build pre Win + Android |

Detailnejší implementačný plán vznikne v ďalšom kroku cez `writing-plans` skill.

---

## 13. Schvaľovanie

- [ ] Používateľ prečítal spec
- [ ] Otvorené otázky (OQ1–OQ3) rozhodnuté
- [ ] Pripomienky zapracované
- [ ] Spec schválený → ide sa robiť implementačný plán
