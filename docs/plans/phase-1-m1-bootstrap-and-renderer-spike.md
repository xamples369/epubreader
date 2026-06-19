# Phase 1 — M1: Bootstrap + Renderer Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stáť na fungujúcom Flutter projekte (Windows build verified, Android infra pripravená) a urobiť hands-on porovnanie troch EPUB renderovacích knižníc na rovnakej sade reálnych kníh — výstupom je ADR s rozhodnutím ktorá knižnica ide do M2.

**Architecture:** Single Flutter app `epubreader` s tromi „spike" obrazovkami v `lib/spike/<candidate>/` — každá načíta EPUB cez `file_picker` a vyrenderuje ho cieľovou knižnicou. Hlavná obrazovka je dočasné menu na výber spike-u. Po rozhodnutí sa porazené spike-y a ich závislosti odstránia, víťaz sa stáva základom pre M2.

**Tech Stack:** Flutter 3.38+, Dart 3.10+, `file_picker`, `flutter_epub_viewer` (WebView+epub.js), `epub_view` (native Dart), `epubx` + `flutter_html` (custom render).

---

## Predpoklady (kontrolný zoznam pred Task 1)

- [x] Flutter SDK ≥ 3.38 (overené: `flutter --version` vracia 3.38.5)
- [x] Windows desktop podpora (overené: `flutter doctor` ✓ Visual Studio)
- [ ] Android cmdline-tools + licencie (rieši sa v **Task 10**, neblokuje Win build)
- [x] Git repo inicializované v `E:\epubreader\`

---

## Súborová mapa (čo na konci M1 v repozitári pribudne)

```
E:\epubreader\
├── pubspec.yaml                 ← Flutter config (CREATE)
├── analysis_options.yaml        ← lint config (CREATE)
├── lib\
│   ├── main.dart                ← app entry, routes (CREATE)
│   ├── spike\
│   │   ├── spike_menu.dart      ← výber spike-u (CREATE)
│   │   ├── flutter_epub_viewer_spike.dart      (CREATE)
│   │   ├── epub_view_spike.dart                (CREATE)
│   │   └── epubx_custom_spike.dart             (CREATE)
│   └── shared\
│       └── fixture_picker.dart  ← spoločný file picker (CREATE)
├── test\
│   ├── smoke_test.dart          ← „aplikácia sa naštartuje" (CREATE)
│   └── fixtures\
│       ├── alice.epub           ← Lewis Carroll, jednoduchý layout (CREATE)
│       ├── pride.epub           ← Austen, dlhšia kniha (CREATE)
│       ├── frankenstein.epub    ← Shelley, kapitoly s rímskymi číslami (CREATE)
│       └── divina.epub          ← Dante, slovenská diakritika v nadpisoch* (CREATE)
├── windows\                     ← generované `flutter create`
├── android\                     ← generované `flutter create`
└── docs\
    └── adr\
        └── 0001-epub-renderer-choice.md   ← výstup M1 (CREATE v Task 9)
```

*Pre slovenskú diakritiku použijeme verziu s preloženými metadátami alebo upravíme OPF — viď Task 5.

---

## Task 1: Flutter scaffold v existujúcom priečinku

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart` (initial Flutter template)
- Create: `windows/`, `android/`, `linux/`, `macos/`, `ios/` (Flutter platform folders)
- Create: `test/widget_test.dart` (Flutter default test)

- [ ] **Step 1.1: Skontroluj že priečinok je čistý okrem našich súborov**

Run:
```
ls
```
Expected: `.git/`, `.gitignore`, `README.md`, `docs/` — nič iné. Ak je tam niečo navyše, zastav a opýtaj sa.

- [ ] **Step 1.2: Spusti `flutter create` v existujúcom priečinku**

Run:
```
flutter create --org app.epubreader --project-name epubreader --platforms=windows,android --description "Adless multi-platform EPUB reader" .
```

Expected: `flutter create` doplní platformové priečinky a `pubspec.yaml`. Existujúce súbory (`README.md`, `docs/`, `.gitignore`) zostanú nedotknuté. Skontroluj že náš `.gitignore` má prednosť — ak `flutter create` pridal svoj vlastný riadok navyše, je to OK, len ho nepretrieme.

- [ ] **Step 1.3: Over že sa appka skompiluje a spustí na Windows**

Run:
```
flutter run -d windows
```

Expected: otvorí sa okno s defaultnou Flutter counter appkou. Klikni na `+` aby si overil interakciu. Potom okno zatvor (alebo Ctrl+C v termináli).

Ak Windows build padne s chybou C++, znamená to že nie sú nainštalované „Desktop development with C++" workloads vo Visual Studio. Inštaláciu si používateľ urobí cez Visual Studio Installer.

- [ ] **Step 1.4: Spusti default widget test**

Run:
```
flutter test
```

Expected: `All tests passed!` (default test counter widgetu).

- [ ] **Step 1.5: Commit**

Run:
```
git add -A
git status
```

Skontroluj že staged sú LEN tieto kategórie: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `test/widget_test.dart`, a všetky platformové priečinky `windows/`, `android/`, `linux/`, `macos/`, `ios/`. Ak je v `git status` `pubspec.lock`, otvor `.gitignore` a over že `pubspec.lock` je tam (mal by byť, dali sme ho do initial gitignore).

Run:
```
git commit -m "chore(m1): bootstrap Flutter project for windows + android"
```

---

## Task 2: Pubspec — pinned versions, minimal deps for M1

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 2.1: Otvor `pubspec.yaml` a nahraď `dependencies` blok**

Otvor `pubspec.yaml`. Mal by tam byť blok ako:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
```

Nahraď ho touto verziou (pridáva spike závislosti — všetky 3 kandidáty + file_picker):

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # File access
  file_picker: ^8.1.4
  path_provider: ^2.1.5

  # EPUB renderer kandidáti (Task 5-7)
  flutter_epub_viewer: ^1.5.1     # WebView + epub.js wrapper
  epub_view: ^3.2.0                # natívny Flutter widget
  epubx: ^4.0.0                    # parser-only, použijeme s flutter_html
  flutter_html: ^3.0.0-beta.2      # HTML render pre epubx spike
```

Zachovaj `dev_dependencies` blok aký je. `flutter` sekciu pod tým takisto.

- [ ] **Step 2.2: Stiahni závislosti**

Run:
```
flutter pub get
```

Expected: `Got dependencies!` bez chýb. Ak konflikt verzií — zastav a zarekrutuj užívateľa, máme rozhodnúť ktorú downgradnúť.

- [ ] **Step 2.3: Over že appka stále kompiluje**

Run:
```
flutter analyze
```

Expected: `No issues found!` (alebo len warnings, žiadne errors).

Run:
```
flutter test
```

Expected: tests pass.

- [ ] **Step 2.4: Commit**

Run:
```
git add pubspec.yaml pubspec.lock
git commit -m "chore(m1): pin spike dependencies (file_picker + 3 epub renderers)"
```

> Poznámka: `pubspec.lock` v MVP/Flutter projektoch býva v `.gitignore`. My ho do M1 commitneme zámerne — pri spike-u chceme reprodukovateľné verzie. Po výbere víťaza v Task 9 prerobíme stratégiu.

Ak `git add pubspec.lock` hlási „ignored", odstráň riadok `pubspec.lock` z `.gitignore`, znovu add, commit. Toto je vedomá výnimka, nie chyba.

---

## Task 3: Skeleton lib štruktúra + spike menu

**Files:**
- Modify: `lib/main.dart` (nahradiť default Flutter counter)
- Create: `lib/spike/spike_menu.dart`

- [ ] **Step 3.1: Vytvor priečinok `lib/spike/`**

Run:
```
mkdir lib/spike
```

- [ ] **Step 3.2: Vytvor `lib/spike/spike_menu.dart`** s týmto presným obsahom:

```dart
import 'package:flutter/material.dart';

class SpikeMenuScreen extends StatelessWidget {
  const SpikeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EPUB Renderer Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vyber spike na vyskúšanie:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/flutter_epub_viewer'),
              child: const Text('1. flutter_epub_viewer (WebView + epub.js)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/epub_view'),
              child: const Text('2. epub_view (natívny Flutter)'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/spike/epubx_custom'),
              child: const Text('3. epubx + flutter_html (custom)'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3.3: Nahraď `lib/main.dart`** kompletne týmto:

```dart
import 'package:flutter/material.dart';

import 'spike/spike_menu.dart';

void main() {
  runApp(const EpubReaderApp());
}

class EpubReaderApp extends StatelessWidget {
  const EpubReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SpikeMenuScreen(),
      routes: {
        // Routes pre spike obrazovky doplníme v Task 5-7.
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not implemented')),
          body: Center(child: Text('Route: ${settings.name}')),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3.4: Aktualizuj smoke test**

Otvor `test/widget_test.dart` a nahraď jeho obsah:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/main.dart';

void main() {
  testWidgets('Spike menu shows three candidate buttons', (tester) async {
    await tester.pumpWidget(const EpubReaderApp());

    expect(find.text('Vyber spike na vyskúšanie:'), findsOneWidget);
    expect(find.textContaining('flutter_epub_viewer'), findsOneWidget);
    expect(find.textContaining('epub_view'), findsOneWidget);
    expect(find.textContaining('epubx + flutter_html'), findsOneWidget);
  });
}
```

- [ ] **Step 3.5: Spusti test**

Run:
```
flutter test
```

Expected: `Spike menu shows three candidate buttons` — pass.

- [ ] **Step 3.6: Vizuálne over na Windows**

Run:
```
flutter run -d windows
```

Expected: po štarte vidíš obrazovku s tromi tlačidlami. Klik na ne (zatiaľ ukáže „Not implemented" pre každý route). Zatvor okno.

- [ ] **Step 3.7: Commit**

Run:
```
git add lib/ test/widget_test.dart
git commit -m "feat(m1): spike menu skeleton with three candidate routes"
```

---

## Task 4: Spoločný fixture picker

**Files:**
- Create: `lib/shared/fixture_picker.dart`

Účel: kód na výber `.epub` súboru cez `file_picker` budú zdieľať všetky tri spike-y. Vyhneme sa duplikácii a zabezpečíme rovnaké vstupné podmienky pri porovnaní.

- [ ] **Step 4.1: Vytvor priečinok `lib/shared/`**

Run:
```
mkdir lib/shared
```

- [ ] **Step 4.2: Vytvor `lib/shared/fixture_picker.dart`** s týmto obsahom:

```dart
import 'package:file_picker/file_picker.dart';

/// Návratový typ — buď cesta k vybranému súboru, alebo null ak používateľ
/// dialog zrušil.
Future<String?> pickEpubFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
    allowMultiple: false,
    dialogTitle: 'Vyber EPUB súbor',
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }
  return result.files.first.path;
}
```

- [ ] **Step 4.3: Over že súbor sa kompiluje**

Run:
```
flutter analyze lib/shared/fixture_picker.dart
```

Expected: `No issues found!`

- [ ] **Step 4.4: Commit**

Run:
```
git add lib/shared/
git commit -m "feat(m1): shared epub file picker for all spike screens"
```

---

## Task 5: Test fixtures (EPUB súbory)

**Files:**
- Create: `test/fixtures/README.md`
- Create: `test/fixtures/*.epub` (4 súbory)

Účel: rovnaká sada reálnych EPUB-ov, na ktorej budeme porovnávať všetky tri kandidáty. Súbory musia byť verejne dostupné (Project Gutenberg) aby sme ich mohli commitnúť do repa bez licenčných problémov.

- [ ] **Step 5.1: Vytvor priečinok**

Run:
```
mkdir -p test/fixtures
```

- [ ] **Step 5.2: Stiahni 4 EPUB-y z Project Gutenberg**

Project Gutenberg sú verejne voľné. Použijeme stabilné direct linky na `.epub` (image-free verzie):

| Súbor | URL | Účel |
|-------|-----|------|
| `alice.epub` | https://www.gutenberg.org/ebooks/11.epub.images | jednoduchý layout, ilustrácie |
| `pride.epub` | https://www.gutenberg.org/ebooks/1342.epub.images | dlhšia kniha (60+ kapitol) |
| `frankenstein.epub` | https://www.gutenberg.org/ebooks/84.epub.images | listy + kapitoly, zmiešaná štruktúra |
| `divina.epub` | https://www.gutenberg.org/ebooks/1012.epub.images | originál v taliančine, diakritika |

Run (PowerShell):
```
Invoke-WebRequest -Uri "https://www.gutenberg.org/ebooks/11.epub.images" -OutFile "test/fixtures/alice.epub"
Invoke-WebRequest -Uri "https://www.gutenberg.org/ebooks/1342.epub.images" -OutFile "test/fixtures/pride.epub"
Invoke-WebRequest -Uri "https://www.gutenberg.org/ebooks/84.epub.images" -OutFile "test/fixtures/frankenstein.epub"
Invoke-WebRequest -Uri "https://www.gutenberg.org/ebooks/1012.epub.images" -OutFile "test/fixtures/divina.epub"
```

Alebo Bash (Git Bash):
```
curl -L -o test/fixtures/alice.epub "https://www.gutenberg.org/ebooks/11.epub.images"
curl -L -o test/fixtures/pride.epub "https://www.gutenberg.org/ebooks/1342.epub.images"
curl -L -o test/fixtures/frankenstein.epub "https://www.gutenberg.org/ebooks/84.epub.images"
curl -L -o test/fixtures/divina.epub "https://www.gutenberg.org/ebooks/1012.epub.images"
```

Expected: 4 EPUB súbory v `test/fixtures/`, každý 200KB–2MB.

- [ ] **Step 5.3: Over že súbory sú validné EPUB-y**

Run (PowerShell):
```
Get-ChildItem test/fixtures/*.epub | ForEach-Object { Write-Host "$($_.Name): $($_.Length) bytes" }
```

Expected: každý súbor > 100KB. Ak je nejaký < 10KB, pravdepodobne sa stiahla HTML chybová stránka — zopakuj download s ručným otvorením URL v prehliadači.

- [ ] **Step 5.4: Vytvor `test/fixtures/README.md`**

```markdown
# Test EPUB Fixtures

Verejne dostupné knihy z [Project Gutenberg](https://www.gutenberg.org/) (public domain).
Slúžia ako rovnaká sada na porovnanie EPUB renderovacích knižníc v M1
a neskôr ako regresné fixtures pre parser/library testy.

| Súbor | Autor | Účel |
|-------|-------|------|
| alice.epub | L. Carroll — *Alice's Adventures in Wonderland* | Jednoduchý layout, vložené ilustrácie |
| pride.epub | J. Austen — *Pride and Prejudice* | Dlhá kniha (~60 kapitol), test výkonu |
| frankenstein.epub | M. Shelley — *Frankenstein* | Zmiešaná štruktúra (listy + kapitoly) |
| divina.epub | D. Alighieri — *La Divina Commedia* | Originál v taliančine, diakritika |

Pri zlyhaní stiahnutia v budúcnosti pozri `docs/plans/phase-1-m1-bootstrap-and-renderer-spike.md` Task 5.
```

- [ ] **Step 5.5: Commit (binárky idú do repa)**

Run:
```
git add test/fixtures/
git commit -m "test(m1): add 4 public-domain epub fixtures for renderer comparison"
```

> Veľkosť commitu: ~3-5 MB. Akceptujeme, lebo M1 závisí od reprodukovateľnej sady.

---

## Task 6: Spike A — `flutter_epub_viewer`

**Files:**
- Create: `lib/spike/flutter_epub_viewer_spike.dart`
- Modify: `lib/main.dart` (zaregistrovať route)

`flutter_epub_viewer` je wrapper okolo `epub.js` cez WebView. Najlepší rendering, ale vyžaduje WebView2 na Windows.

- [ ] **Step 6.1: Vytvor `lib/spike/flutter_epub_viewer_spike.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

import '../shared/fixture_picker.dart';

class FlutterEpubViewerSpikeScreen extends StatefulWidget {
  const FlutterEpubViewerSpikeScreen({super.key});

  @override
  State<FlutterEpubViewerSpikeScreen> createState() =>
      _FlutterEpubViewerSpikeScreenState();
}

class _FlutterEpubViewerSpikeScreenState
    extends State<FlutterEpubViewerSpikeScreen> {
  final EpubController _controller = EpubController();
  String? _path;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() => _error = null);
    final p = await pickEpubFile();
    if (p == null) return;
    setState(() => _path = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike A — flutter_epub_viewer'),
        actions: [
          IconButton(
            tooltip: 'Otvoriť EPUB',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Chyba: $_error'));
    }
    if (_path == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    return EpubViewer(
      epubSource: EpubSource.fromFile(_path!),
      epubController: _controller,
      displaySettings: EpubDisplaySettings(
        flow: EpubFlow.paginated,
        snap: true,
      ),
      onChaptersLoaded: (chapters) {
        debugPrint(
          'flutter_epub_viewer: loaded ${chapters.length} chapters',
        );
      },
      onEpubLoaded: () => debugPrint('flutter_epub_viewer: ready'),
      onRelocated: (location) {
        debugPrint('flutter_epub_viewer: at ${location.startCfi}');
      },
    );
  }
}
```

- [ ] **Step 6.2: Pridaj route do `lib/main.dart`**

Nájdi v `lib/main.dart` blok:

```dart
      routes: {
        // Routes pre spike obrazovky doplníme v Task 5-7.
      },
```

Nahraď ho:

```dart
      routes: {
        '/spike/flutter_epub_viewer': (_) => const FlutterEpubViewerSpikeScreen(),
      },
```

A pridaj import navrch súboru:

```dart
import 'spike/flutter_epub_viewer_spike.dart';
```

- [ ] **Step 6.3: Skompiluj a spusti**

Run:
```
flutter run -d windows
```

V appke:
1. Klikni „1. flutter_epub_viewer …"
2. Klikni ikonu priečinka vpravo hore.
3. Vyber `test/fixtures/alice.epub`.
4. Kniha by sa mala vyrenderovať. Skús swipe / klik na okraje.

Expected na Windows: ak chýba WebView2 runtime, dostaneš biele okno alebo chybu. WebView2 runtime nainštaluj z https://developer.microsoft.com/microsoft-edge/webview2/ (alebo už je súčasťou Win11 — typicky áno).

Ak rendering pracuje, **zapíš si v hlave (alebo do notesu)** subjektívne dojmy: rýchlosť otvorenia, kvalita textu, fungujú stránky, fungujú ilustrácie, fungujú slovenské znaky pri `divina.epub`.

- [ ] **Step 6.4: Spusti widget test**

Run:
```
flutter test
```

Expected: existing smoke test stále passes.

- [ ] **Step 6.5: Commit**

Run:
```
git add lib/spike/flutter_epub_viewer_spike.dart lib/main.dart
git commit -m "feat(m1): spike A — flutter_epub_viewer (WebView + epub.js)"
```

---

## Task 7: Spike B — `epub_view`

**Files:**
- Create: `lib/spike/epub_view_spike.dart`
- Modify: `lib/main.dart` (zaregistrovať route)

`epub_view` je natívny Flutter widget — žiadny WebView, vlastný render textov a obrázkov.

- [ ] **Step 7.1: Vytvor `lib/spike/epub_view_spike.dart`**

```dart
import 'dart:io';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';

import '../shared/fixture_picker.dart';

class EpubViewSpikeScreen extends StatefulWidget {
  const EpubViewSpikeScreen({super.key});

  @override
  State<EpubViewSpikeScreen> createState() => _EpubViewSpikeScreenState();
}

class _EpubViewSpikeScreenState extends State<EpubViewSpikeScreen> {
  EpubController? _controller;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _controller = null;
    });
    final p = await pickEpubFile();
    if (p == null) return;
    try {
      final bytes = await File(p).readAsBytes();
      final controller = EpubController(
        document: EpubDocument.openData(bytes),
      );
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = e.toString());
    }
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
        title: const Text('Spike B — epub_view'),
        actions: [
          IconButton(
            tooltip: 'Otvoriť EPUB',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Chyba: $_error'));
    }
    final c = _controller;
    if (c == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    return EpubView(controller: c);
  }
}
```

- [ ] **Step 7.2: Pridaj route do `lib/main.dart`**

V bloku `routes:` pridaj druhý záznam:

```dart
      routes: {
        '/spike/flutter_epub_viewer': (_) => const FlutterEpubViewerSpikeScreen(),
        '/spike/epub_view': (_) => const EpubViewSpikeScreen(),
      },
```

A pridaj import:

```dart
import 'spike/epub_view_spike.dart';
```

- [ ] **Step 7.3: Skompiluj a spusti**

Run:
```
flutter run -d windows
```

V appke:
1. Klikni „2. epub_view …"
2. Otvor `test/fixtures/alice.epub`.
3. Skús scroll, otestuj zobrazenie obrázku a diakritiky.
4. Otvor `test/fixtures/pride.epub` — sleduj rýchlosť načítania (60 kapitol).

Zapíš si dojmy: rýchlosť, kvalita textu, ovládanie scroll/stránok, fungujú obrázky a slovenské znaky.

- [ ] **Step 7.4: Commit**

Run:
```
git add lib/spike/epub_view_spike.dart lib/main.dart
git commit -m "feat(m1): spike B — epub_view (native Flutter widget)"
```

---

## Task 8: Spike C — `epubx` + `flutter_html`

**Files:**
- Create: `lib/spike/epubx_custom_spike.dart`
- Modify: `lib/main.dart` (zaregistrovať route)

Tento spike je „custom" — používa `epubx` len na parsovanie EPUB-u a `flutter_html` na vykreslenie HTML obsahu kapitoly za kapitolou. Ukazuje koľko by stálo postaviť vlastný renderer.

- [ ] **Step 8.1: Vytvor `lib/spike/epubx_custom_spike.dart`**

```dart
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../shared/fixture_picker.dart';

class EpubxCustomSpikeScreen extends StatefulWidget {
  const EpubxCustomSpikeScreen({super.key});

  @override
  State<EpubxCustomSpikeScreen> createState() =>
      _EpubxCustomSpikeScreenState();
}

class _EpubxCustomSpikeScreenState extends State<EpubxCustomSpikeScreen> {
  EpubBook? _book;
  int _chapterIndex = 0;
  String? _error;

  Future<void> _pickAndLoad() async {
    setState(() {
      _error = null;
      _book = null;
      _chapterIndex = 0;
    });
    final p = await pickEpubFile();
    if (p == null) return;
    try {
      final bytes = await File(p).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      setState(() => _book = book);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spike C — epubx + flutter_html'),
        actions: [
          IconButton(
            tooltip: 'Otvoriť EPUB',
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndLoad,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _book == null
          ? null
          : _buildChapterNav(_book!.Chapters?.length ?? 0),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Chyba: $_error'));
    }
    final book = _book;
    if (book == null) {
      return const Center(
        child: Text('Klikni na priečinok hore a vyber .epub'),
      );
    }
    final chapters = book.Chapters ?? [];
    if (chapters.isEmpty) {
      return const Center(child: Text('Kniha nemá žiadne kapitoly.'));
    }
    final chapter = chapters[_chapterIndex];
    final html = chapter.HtmlContent ?? '<p>(prázdna kapitola)</p>';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(data: html),
    );
  }

  Widget _buildChapterNav(int count) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _chapterIndex > 0
                ? () => setState(() => _chapterIndex--)
                : null,
          ),
          Text('Kapitola ${_chapterIndex + 1} / $count'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _chapterIndex < count - 1
                ? () => setState(() => _chapterIndex++)
                : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8.2: Pridaj route do `lib/main.dart`**

Aktualizuj routes:

```dart
      routes: {
        '/spike/flutter_epub_viewer': (_) => const FlutterEpubViewerSpikeScreen(),
        '/spike/epub_view': (_) => const EpubViewSpikeScreen(),
        '/spike/epubx_custom': (_) => const EpubxCustomSpikeScreen(),
      },
```

A import:

```dart
import 'spike/epubx_custom_spike.dart';
```

- [ ] **Step 8.3: Skompiluj a spusti**

Run:
```
flutter run -d windows
```

1. Klikni „3. epubx + flutter_html…".
2. Otvor `test/fixtures/alice.epub`.
3. Lístuj kapitolami šípkami dole.
4. Skús všetky 4 fixtures.

Zapíš si dojmy. Tu sa pozri najmä na to **koľko je to ešte ďaleko od „použiteľnej čítačky"** — obrázky, fonty, štýly knihy. Toto je proxy pre „koľko práce by stálo dorobiť to vlastným renderom".

- [ ] **Step 8.4: Commit**

Run:
```
git add lib/spike/epubx_custom_spike.dart lib/main.dart
git commit -m "feat(m1): spike C — epubx parser + flutter_html render"
```

---

## Task 9: Porovnanie a rozhodnutie (ADR)

**Files:**
- Create: `docs/adr/0001-epub-renderer-choice.md`
- Modify: `docs/specs/phase-1-mvp.md` (zafixovať voľbu v §3)
- Modify: `README.md` (zaškrtnúť M1 hotové)

- [ ] **Step 9.1: Vytvor priečinok**

Run:
```
mkdir -p docs/adr
```

- [ ] **Step 9.2: Pretestuj všetky 4 fixtures cez všetky 3 spike-y**

Pre každú kombináciu (3 × 4 = 12) zapíš si do tabuľky odpovede:

| Kritérium | Váha | flutter_epub_viewer | epub_view | epubx+html |
|----------|------|-----|-----|-----|
| Renderuje text čitateľne | 5 | ?/5 | ?/5 | ?/5 |
| Diakritika v `divina.epub` | 4 | ?/5 | ?/5 | ?/5 |
| Obrázky v `alice.epub` | 3 | ?/5 | ?/5 | ?/5 |
| Rýchlosť otvorenia `pride.epub` (60 kap.) | 3 | ?/5 | ?/5 | ?/5 |
| Pagination feeling (preklik stranou) | 4 | ?/5 | ?/5 | ?/5 |
| Scroll feeling | 4 | ?/5 | ?/5 | ?/5 |
| Kvalita typografie (riadkovanie, kerning) | 3 | ?/5 | ?/5 | ?/5 |
| Stabilita (žiadne pády) | 5 | ?/5 | ?/5 | ?/5 |
| **Vážený súčet** | — | **?** | **?** | **?** |

Vážený súčet = `Σ(skóre × váha)`. Najvyšší výsledok je víťaz, ALE — pozri si aj kvalitatívne dojmy. Ak je víťaz technicky najlepší ale subjektívne ho neznášaš, hraj na druhého. Tvoja appka, tvoje pravidlá.

- [ ] **Step 9.3: Vytvor `docs/adr/0001-epub-renderer-choice.md`**

Použi tento template — vyplň konkrétne čísla a doplň 2-3 vety k „Dôvod":

```markdown
# ADR 0001 — Voľba EPUB renderovacej knižnice

**Status:** Accepted
**Dátum:** 2026-06-20
**Kontext:** M1 spike, Fáza 1 (MVP)

## Kontext

Spec Fázy 1 (`docs/specs/phase-1-mvp.md`, §3) označil výber EPUB renderera za
najväčšie riziko MVP. Tri kandidáti boli prakticky vyskúšaní v M1 na
identickej sade 4 EPUB súborov:

- `alice.epub` — jednoduchý layout + ilustrácie
- `pride.epub` — dlhá kniha, výkon
- `frankenstein.epub` — zmiešaná štruktúra
- `divina.epub` — diakritika

## Skórovanie

| Kritérium | Váha | flutter_epub_viewer | epub_view | epubx+html |
|----------|------|-----|-----|-----|
| (skopíruj vyplnenú tabuľku z Task 9.2) |

## Rozhodnutie

**Vybraný kandidát:** `<doplň meno knižnice>`

## Dôvod

(2-4 vety: prečo víťaz vyhral, čo bolo rozhodujúce kritérium, akú zľavu robíme
v iných kritériách)

## Dôsledky

- Pubspec ostáva s `<víťaz>` ako primárnou dep, ostatné dva sa odstránia (Task 10).
- M2 (Library + DB backbone) implementuje `EpubRenderer` rozhranie nad víťaznou knižnicou.
- Pri vážnejších problémoch v M3 (Reader v1) sa môžeme vrátiť k tomuto ADR a urobiť „supersede" voľbu.

## Alternatívy zamietnuté

- **flutter_epub_viewer:** (krátke prečo nie, ak nevybraný)
- **epub_view:** (krátke prečo nie, ak nevybraný)
- **epubx + flutter_html:** (krátke prečo nie, ak nevybraný)
```

- [ ] **Step 9.4: Aktualizuj spec — zafixuj voľbu**

Otvor `docs/specs/phase-1-mvp.md`, nájdi v §3 časť „EPUB rendering: rozhoduje sa v Mileniku M1…" a nahraď zoznamom víťaza s odkazom na ADR:

```markdown
- **EPUB rendering:** `<víťaz>` — výber zafixovaný v [ADR 0001](../adr/0001-epub-renderer-choice.md).
```

- [ ] **Step 9.5: Aktualizuj README.md**

V `README.md` v sekcii „Fáza 1 — MVP" zaškrtni:

```markdown
- [x] Výber a otestovanie EPUB renderovacej knižnice
```

V sekcii „Aktuálny stav" aktualizuj:

```markdown
**Fáza:** Fáza 1 (MVP) — M1 hotový, ideme na M2
**Posledná aktualizácia:** 2026-06-20

### Hotové
... (zachovaj existujúce)
- [x] M1: Bootstrap Flutter projektu + ADR 0001 (renderer choice)

### Najbližší krok
1. Plán pre M2 (Library + DB backbone) cez writing-plans
2. Implementácia M2
```

- [ ] **Step 9.6: Commit**

Run:
```
git add docs/adr/ docs/specs/phase-1-mvp.md README.md
git commit -m "docs(m1): adr 0001 — chose <vitaz> as epub renderer"
```

(Nahraď `<vitaz>` skutočným menom knižnice.)

---

## Task 10: Cleanup — odstránenie porazených spike-ov

**Files:**
- Modify: `pubspec.yaml` (zhodiť 2 z 3 EPUB knižníc + `flutter_html`)
- Delete: 2 z 3 súborov `lib/spike/<porazený>_spike.dart`
- Modify: `lib/main.dart` (odstrániť routes a imports porazených)
- Modify: `lib/spike/spike_menu.dart` (premenovať na „dev menu" alebo odstrániť)

- [ ] **Step 10.1: Otvor `pubspec.yaml` a odstráň závislosti porazených**

Z bloku `dependencies` odstráň riadky pre 2 porazené knižnice. Ak vyhral:

- **flutter_epub_viewer** → odstráň `epub_view: ...`, `epubx: ...`, `flutter_html: ...`
- **epub_view** → odstráň `flutter_epub_viewer: ...`, `epubx: ...`, `flutter_html: ...`
- **epubx+html** → odstráň `flutter_epub_viewer: ...`, `epub_view: ...` (epubx a flutter_html ostanú)

- [ ] **Step 10.2: Stiahni lockfile**

Run:
```
flutter pub get
```

Expected: tranzitívne závislosti porazených zmiznú, lockfile sa zmenší.

- [ ] **Step 10.3: Odstráň súbory porazených spike-ov**

Run (príklad ak vyhral `epub_view`):
```
rm lib/spike/flutter_epub_viewer_spike.dart
rm lib/spike/epubx_custom_spike.dart
```

(Uprav podľa skutočného víťaza.)

- [ ] **Step 10.4: Vyčisti `lib/main.dart`**

Odstráň zodpovedajúce importy a routes. Z `routes:` ponechaj len víťazov route. Z `home:` ponechaj `SpikeMenuScreen` zatiaľ (v M2 ho nahradíme reálnym domovom).

- [ ] **Step 10.5: Vyčisti `lib/spike/spike_menu.dart`**

Odstráň tlačidlá ktoré ukazovali na porazené spike-y. Zostane jedno tlačidlo — vstup do víťaza. V M2 toto celé menu nahradíme reálnou Home obrazovkou.

- [ ] **Step 10.6: Aktualizuj smoke test**

V `test/widget_test.dart` zmen kontrolu tak aby:
- testovala že menu obsahuje **jedno** tlačidlo s názvom víťaza,
- žiadne odkazy na porazených.

Príklad pre víťaza `epub_view`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/main.dart';

void main() {
  testWidgets('Dev menu shows the chosen renderer route', (tester) async {
    await tester.pumpWidget(const EpubReaderApp());

    expect(find.textContaining('epub_view'), findsOneWidget);
    expect(find.textContaining('flutter_epub_viewer'), findsNothing);
    expect(find.textContaining('epubx'), findsNothing);
  });
}
```

- [ ] **Step 10.7: Over všetko stále funguje**

Run:
```
flutter analyze
flutter test
flutter run -d windows
```

Expected: analyze čistá, testy passes, app sa spustí, klik na zostávajúce tlačidlo otvorí spike s víťazom, otvorenie EPUB-u funguje.

- [ ] **Step 10.8: Commit**

Run:
```
git add -A
git status
```

Skontroluj že staged sú: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `lib/spike/spike_menu.dart`, smazané súbory porazených, upravený `test/widget_test.dart`.

Run:
```
git commit -m "chore(m1): drop losing renderer candidates, keep <vitaz>"
```

---

## Task 11: Android setup (môže byť aj neskôr)

Tento task je „nice to have" pre M1, kritický pre M2. Ak chceš teraz, urob ho; ak nie, presunieme do začiatku M2.

**Files:**
- (žiadne — len konfigurácia prostredia)

- [ ] **Step 11.1: Inštaluj cmdline-tools**

Otvor **Android Studio** (ak nie je, stiahni z https://developer.android.com/studio).
V Android Studio → `More Actions` → `SDK Manager` → záložka `SDK Tools` → zaškrtni
**Android SDK Command-line Tools (latest)** → Apply.

- [ ] **Step 11.2: Akceptuj licencie**

Run:
```
flutter doctor --android-licenses
```

Stláčaj `y` pri každej prompt-e.

- [ ] **Step 11.3: Over že emulator sa naštartuje**

Spusti emulator z Android Studio (`Device Manager` → ikona play pri existujúcom emulatore).
Alebo cez CLI:
```
flutter emulators
flutter emulators --launch <emulator_id>
```

- [ ] **Step 11.4: Spusti appku na emulatore**

Run:
```
flutter run -d emulator-5554
```

(ID emulatora preber z `flutter devices`.)

Expected: appka sa spustí v emulatore, klik na víťaza otvorí spike, otvorenie EPUB-u funguje aj na Androide.

- [ ] **Step 11.5: Commit (žiadne kódové zmeny, len markdown poznámka)**

Aktualizuj `README.md` — v sekcii M1 zaškrtni „Build pre Android":

```markdown
- [x] Build pre Android
```

Run:
```
git add README.md
git commit -m "docs(m1): android build verified on emulator"
```

---

## Akceptačné kritériá M1

- [x] Flutter projekt vznikol v `E:\epubreader\` bez prepísania existujúcich súborov.
- [ ] `flutter test` prebehne zelený.
- [ ] `flutter run -d windows` otvorí appku a víťazný renderer dokáže vyrenderovať všetky 4 fixtures.
- [ ] (voliteľné — Task 11) `flutter run -d emulator-XXXX` to isté na Androide.
- [ ] ADR 0001 existuje, je commitnutý, je v ňom konkrétne meno víťaza a 2-4 vetné odôvodnenie.
- [ ] Pubspec obsahuje len víťaza (a tranzitívne závislosti), porazení sú odstránení.
- [ ] README.md odráža stav „M1 hotový, ideme na M2".

---

## Po M1

Vytvorenie plánu pre **M2 (Library + DB + Settings backbone)** sa robí znova cez `superpowers:writing-plans` — budeme stavať nad rozhodnutím z ADR 0001.
