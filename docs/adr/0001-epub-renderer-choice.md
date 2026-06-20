# ADR 0001 — Voľba EPUB renderovacej knižnice

**Status:** Draft — čaká na vyhodnotenie spike-ov
**Dátum:** 2026-06-20
**Kontext:** M1 spike, Fáza 1 (MVP)

## Kontext

Spec Fázy 1 (`docs/specs/phase-1-mvp.md`, §3 a §9.R1) označil výber EPUB
renderera za najväčšie riziko MVP. V M1 vznikli prakticky vyskúšateľné
prototypy troch kandidátov, ktoré sa porovnávajú na rovnakej sade
4 EPUB súborov:

- `test/fixtures/alice.epub` — jednoduchý layout + ilustrácie
- `test/fixtures/pride.epub` — dlhá kniha (24 MB s obrázkami)
- `test/fixtures/frankenstein.epub` — zmiešaná štruktúra (listy + kapitoly)
- `test/fixtures/divina.epub` — diakritika (talianske akcenty)

Spike-y sú dostupné cez tri tlačidlá z domovskej obrazovky aplikácie.

## Skórovanie

Stupnica: 1 (nepoužiteľné) — 2 (zlé) — 3 (akceptovateľné) — 4 (dobré) — 5 (skvelé).
Vyplň `?` skutočným číslom po vyskúšaní každého spike-u na každom fixture.

| Kritérium | Váha | flutter_epub_viewer | epub_view | epubx+html |
|----------|------|-----|-----|-----|
| Renderuje text čitateľne | 5 | ?/5 | ?/5 | ?/5 |
| Diakritika v `divina.epub` | 4 | ?/5 | ?/5 | ?/5 |
| Obrázky v `alice.epub` | 3 | ?/5 | ?/5 | ?/5 |
| Rýchlosť otvorenia `pride.epub` | 3 | ?/5 | ?/5 | ?/5 |
| Pagination/scroll feeling | 4 | ?/5 | ?/5 | ?/5 |
| Kvalita typografie (riadkovanie, kerning) | 3 | ?/5 | ?/5 | ?/5 |
| Stabilita (žiadne pády) | 5 | ?/5 | ?/5 | ?/5 |
| **Vážený súčet** | — | **?** | **?** | **?** |

Vážený súčet = `Σ(skóre × váha)`. Maximum: `(5+4+3+3+4+3+5) × 5 = 135`.

## Rozhodnutie

**Vybraný kandidát:** _(doplniť po skórovaní)_

## Dôvod

_(2-4 vety: prečo víťaz vyhral, čo bolo rozhodujúce kritérium, akú zľavu robíme
v iných kritériách)_

## Dôsledky

- Pubspec ostáva s `<víťaz>` ako primárnou dep, ostatné dva sa odstránia (Task 10).
- M2 (Library + DB backbone) implementuje `EpubRenderer` rozhranie nad víťaznou knižnicou.
- Pri vážnejších problémoch v M3 (Reader v1) sa môžeme vrátiť k tomuto ADR a urobiť „supersede" voľbu.

## Alternatívy zamietnuté

### flutter_epub_viewer
_(krátke prečo nie, ak nevybraný)_

### epub_view
_(krátke prečo nie, ak nevybraný)_

### epubx + flutter_html
_(krátke prečo nie, ak nevybraný)_

## Príloha: Pozorovania počas testovania

_(voľne písané poznámky čo ťa zaujalo — môže pomôcť pri neskorších rozhodnutiach)_

- flutter_epub_viewer:
  -
- epub_view:
  -
- epubx + flutter_html:
  -
