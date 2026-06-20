# ADR 0001 — Voľba EPUB renderovacej knižnice

**Status:** Accepted
**Dátum:** 2026-06-20
**Kontext:** M1 spike, Fáza 1 (MVP)

## Kontext

Spec Fázy 1 (`docs/specs/phase-1-mvp.md`, §3 a §9.R1) označil výber EPUB
renderera za najväčšie riziko MVP. V M1 vznikli prakticky vyskúšateľné
prototypy troch kandidátov, ktoré sa porovnávali na rovnakej sade
test fixtures:

- `test/fixtures/alice.epub` — jednoduchý layout + ilustrácie
- `test/fixtures/pride.epub` — dlhá kniha (24 MB s obrázkami)
- `test/fixtures/frankenstein.epub` — zmiešaná štruktúra (listy + kapitoly)
- `test/fixtures/divina.epub` — diakritika (talianske akcenty)

## Skórovanie

| Kritérium | Váha | flutter_epub_viewer | epub_view | epubx + flutter_html |
|-----------|------|--------------------:|----------:|---------------------:|
| Renderuje text čitateľne | 5 | — (crash) | 4/5 | 3/5 |
| Pôsobí ako reálna čítačka | 4 | — (crash) | 4/5 | 2/5 |
| Stabilita (žiadne pády) | 5 | 1/5 | 5/5 | 5/5 |
| Pripravenosť na pagination + scroll | 4 | — | 5/5 | 1/5 |
| Náklady na dostavbu UX | 3 | — | nízke | vysoké |
| **Záver** | — | **vyradený** | **víťaz** | **záloha** |

> Poznámka: flutter_epub_viewer dokázal načítať a sparsovať EPUB (debugPrint
> potvrdil 16 kapitol z `alice.epub`), ale pri vykresľovaní vo WebView2
> proces aplikácie natvrdo padol („Lost connection to device" v `flutter run`
> bez Dart tracebacku — typicky pád na natívnej WebView2 strane). Na
> aktuálnom Windows 11 + VS 2026 prostredí je nestabilný a nie je dôvod
> riskovať pri stavbe MVP-čky.

## Rozhodnutie

**Vybraný kandidát: `epub_view`** (verzia ^3.2.0).

## Dôvod

Pri identickom teste (otvorenie `alice.epub`) `epub_view` plynule vyrenderoval
text aj obrázky, je to čistý Dart/Flutter widget (žiadne WebView závislosti),
a balík už interne podporuje oba čítacie módy (paginated/scroll), TOC
navigáciu, externé/interné odkazy a callbacky pre pozíciu — všetko čo
MVP-čka potrebuje v M3 a M4 bez budovania od nuly. `flutter_epub_viewer`
crashol natvrdo, `epubx + flutter_html` síce funguje, ale je to len parser
plus jednorazový HTML render — celé čítanie (zostavovanie strán, prechody
medzi kapitolami, internál linky, embedded obrázky vo všetkých formátoch)
by sme museli postaviť ručne.

## Dôsledky

- Pubspec ostáva s **`epub_view: ^3.2.0`** ako primárnou EPUB závislosťou.
  V Task 10 sa odstránia `flutter_epub_viewer`, `epubx`, `flutter_html` aj
  ich spike obrazovky a `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`
  define v `windows/CMakeLists.txt` (bol potrebný len kvôli
  `flutter_inappwebview_windows`, ktorý odíde s `flutter_epub_viewer`).
- M2 (Library + DB backbone) postaví doménový `EpubRenderer` interface,
  ktorý sa v M3 implementuje nad `epub_view`. Interface zachová možnosť
  vymeniť renderer neskôr bez prepisovania UI.
- Ak v M3/M4 narazíme na vážny problém (napr. `epub_view` nevie
  niečo špecifické), môžeme tento ADR „supersede-núť" a vrátiť sa
  k `epubx + flutter_html`, ktorý zostane zdokumentovaný ako fallback.

## Alternatívy zamietnuté

### flutter_epub_viewer
Padá natvrdo pri renderovaní na aktuálnom Windows prostredí (VS 2026 18.x,
WebView2). Aj keby sa to ladením spravilo, WebView2 závislosť pridáva veľký
runtime, vyžaduje extra define (`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`)
kvôli zastaranému `<experimental/coroutine>` v plugine, a celkovo zvyšuje
riziko na Windows aj Androide. Pre čítačku knihy je natívny widget bezpečnejší.

### epubx + flutter_html
Funguje a parsuje EPUB-y bez problémov, ale je to len parser + HTML render
jednej kapitoly. Všetka pridaná hodnota čítačky (plynulé prechody, TOC,
pagination, internál linky, embedded obrázky) by sme museli vybudovať
sami. Pre MVP to predstavuje veľa „re-implementácie kolesa" navyše voči
`epub_view`, ktorý to už má. Zostáva ale ako zaujímavá záloha — `epubx`
samotný je výborný parser a v budúcnosti ho môžeme stále využiť napr. na
metadata extraction v knižnici.

## Príloha: Pozorovania počas testovania

- **flutter_epub_viewer:** parser dobehol (16 kapitol z `alice.epub`),
  rendering vo WebView2 spadol bez Dart tracebacku.
- **epub_view:** renderoval `alice.epub` čisto, používateľovi sadlo
  („pekné, ako čítačka"). Šípky a pagination zatiaľ nemá (to nie je úloha
  spike-u), ale knižnica oboje vie z koroby — dorobí sa v M3/M4.
- **epubx + flutter_html:** funguje, chapter-by-chapter navigation cez naše
  šípky je raw ale spoľahlivé. Limit: neukladá medzistav, nemá pagination
  ani plynulé pokračovanie medzi kapitolami.
