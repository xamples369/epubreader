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

## S1 — EpubController API investigation

_(vznikne počas T2)_

---

## S2-S7 commit SHAs

_(vznikne počas T3-T8)_

---

## Plán A vs Plán B pre RP resolve

_(rozhodnutie po S1 spike-u)_
