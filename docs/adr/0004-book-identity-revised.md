# ADR 0004 — Book Identity (Revised)

**Status:** Accepted
**Dátum:** 2026-06-21
**Supersedes:** [ADR 0003](0003-book-identity.md)
**Related:** ADR 0002 (anchor format), `docs/specs/m2.6-book-identity.md`,
`docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md` §5

---

## Kontext

ADR 0003 prezentoval prvý návrh book identity. Code review odhalil 4 vady:

- **P1 — Coupling:** identity volala `CanonicalChapterText.extract` (M2.5)
  čo je shared s anchor matching-om. Anchor normalize je navrhnutý tak aby
  rástol (objavili sme to v S0 GATE — pridanie typografickej reconciliation).
  Identita musí byť zamrznutá naveky; coupling by spôsobil že každé budúce
  vylepšenie anchor normalize ticho zmení hash každej knihy → osirotené
  highlighty pri update appky.
- **P2 — Incomplete hash:** iterácia cez `book.Chapters` (postavené z TOC/NCX)
  vynechávala podkapitoly (`EpubChapter.SubChapters`). Divina Commedia s
  Inferno/Purgatorio/Paradiso ako top-level a jednotlivé cantos ako podkapitoly
  produkovala hash z ~5 % skutočného obsahu knihy. Testy „4 fixtures = 4 rôzne
  hashe" tento bug nezachytili — stačilo aby sa knihy líšili v top-level.
- **P3 — Fragile metadata:** TITLE/AUTHORS/LANG v hash-i pridávali krehkosť
  (oprava preklepu v názve → osirotené anchory) za nulový rozlišovací zisk.
  Jediný prípad kde metadata zachránia je „dva legitímne rôzne tituly s
  bajtovo identickým plným textom" — degenerovaný scenár.
- **Drobnosť — fallback:** `#$i` (index v `book.Chapters`) nesedel s anchor
  `#<spineIndex>` (ADR 0002 §4.3) ak sa poradia líšili.

Naviac procesná vec: ADR 0003 bol prepísateľný v mieste „Accepted", čo by
zahmľovalo audit trail. Tento nový ADR preto 0003 superseduje, neprepisuje.

## Rozhodnutie

**Algoritmus:** SHA-256 hex (64 znakov, lowercase, `[0-9a-f]+`).

**Schéma verzia:** `BookIdentity.schemeVersion = 1`. Konštanta je zafixovaná
v kóde. **Anchory (ADR 0002) sa scopujú na `(bookHash, schemeVersion)`** —
keď v budúcnosti bumpneme verziu, vieme detegovať „starý hash, neresolve-uj
anchory naprieč verziami, treba migrácia". Migrácia je explicitná, nie tichá.

**Vstup pre SHA-256** (UTF-8):

```
SCHEME:1
ITEM:<href1>:<frozen normalized text>
ITEM:<href2>:<frozen normalized text>
...
```

Žiadne metadata (TITLE/AUTHORS/LANG). Žiadny chapter-index fallback (spine
itemref vždy má manifest href; ak nie, je to malformed EPUB — skipujeme item
gracefully).

### Iterácia obsahu — spine, nie chapters

Enumeruje sa `book.Schema.Package.Spine.Items` (reading order, kompletné,
**vrátane `linear="no"` itemov** pre deterministickú kompletnosť).
Pre každý `IdRef` sa cez `book.Schema.Package.Manifest.Items` mapuje na `Href`.
Neresolvnuteľný idref (žiadny match v manifest-e) → skip gracefully.

Raw HTML sa získa cez `book.Content?.Html?[href]` → `EpubTextContentFile.Content`.
Pretože manifest hrefs sú zvyčajne relatívne k OPF adresáru (`Text/ch1.xhtml`),
zatiaľ čo `book.Content.Html` môže byť kľúčované plnou cestou od ZIP rootu
(`OEBPS/Text/ch1.xhtml`), pri lookup-e skúšame variant:

1. priamy match
2. `key.endsWith('/$href')` alebo `href.endsWith('/$key')`
3. zhoda basename (poslednej cesty)

Ak žiadny variant nepasuje → prázdny text pre tento item (item sa zarátá ale
prispieva 0 znakov). To je akceptované (rare malformed EPUB), nepadáme.

### Frozen identity normalize

**`_identityNormalize`** je private, statické, **zamrznuté pod
`schemeVersion`**. Postup:

1. **`package:html` parse** raw HTML → DOM
2. Extract `document.body?.text` (alebo `documentElement.text` fallback)
3. Whitespace collapse (`\s+` → ` `)
4. Trim

`package:html` deterministicky dekóduje **všetky** named aj numeric HTML
entity (`&mdash;`, `&hellip;`, `&rsquo;`, `&copy;`, `&#160;`, `&#xA0;`, …).
Konkrétny dôvod prečo NIE hand-roll regex tag-strip + zoznam štyroch entít:
neúplný entity zoznam by spôsobil že raz `&mdash;` ostane ako literál a inde
sa dekóduje → rôzny hash + nesprávne extrahovaný text. To je presne tá
nestabilita ktorú scheme má odstrániť.

**Žiadne** typografické reconciliations (smart→straight quotes, em-dash→hyphen).
**Žiadne** soft hyphen strip. **Žiadne** Unicode NFC normalization. Tieto sú
vlastnosti anchor matching-u (M2.5) ktoré sa môžu vyvíjať nezávisle. Identita
je iná zodpovednosť: **stabilita > flexibilita**.

> **Dôsledok:** soft-hyphen variant alebo Unicode-form rozdiel (NFC vs NFD)
> medzi dvomi súbormi sa ráta ako „iná kniha". Pre reálny sync scenár (ten
> istý súbor na dvoch zariadeniach = bajtovo identický) je toto bezvýznamné.
> Cross-edícia je už predtým out of scope (ADR 0002 §4.3).

## Reálne hash-y zo 4 fixtures (verifikácia po revíznych zmenách)

```
alice.epub:        b81d840b0114e2d9efe7aa5239c124d3f77b17dcff83de9ddc87cf6c3cfa0b71
pride.epub:        697eabf19178d8e03636ba499c9117cf51c893a62d5a48eca1ab441e37a4762a
frankenstein.epub: 513743c077a70eec37fcfb4ba9ddbc019a8b480c7922a32c122d69ed8dc038d7
divina.epub:       9de4f972323580572192ffcbc6940cd2f669e77dcfd34d0b6d0c19805273887a
```

### Canonical input lengths (P2 verifikácia)

| Fixture | Input length (chars) | Pozn. |
|---------|----------------------|-------|
| alice.epub | ~162 000 | malá kniha, ~12 chapters, OK |
| pride.epub | ~733 000 | dlhá kniha, 61 kapitol — plný text v hash-i |
| frankenstein.epub | ~438 000 | listy + kapitoly — plný text |
| divina.epub | ~547 000 | **3 cantiche × ~33 cantos** — plný text vrátane podkapitol |

Test `spine iteration covers full book — divina has rich text (>200K chars)`
toto trvalo overuje v test suite. Ak by P2 regression vznikol (návrat k
`book.Chapters` iteration), divina test by zlyhal na hraničnej hodnote.

## Stabilita

| Scenár | Hash | Pozn. |
|--------|------|-------|
| Rovnaký súbor, dvakrát načítaný | rovnaký | testované |
| Rovnaký obsah v novom ZIP (iný compression / timestamps) | rovnaký | hash čerpá z manifest + content map, nie ZIP metadata |
| Iné vydanie (iný preklad, doplnené kapitoly) | rôzny | spine obsah sa líši |
| Drobné editácie textu (oprava preklepu) | rôzny | content-sensitive — chápeme to ako iné vydanie |
| Zmenené metadata (názov, autor) pri rovnakom obsahu | **rovnaký** | metadata nie sú v hash-i (P3 fix) |
| Zmenená obálka, rovnaký text | rovnaký | cover nie je v hash-i |
| Soft hyphen / Unicode forma sa líši | rôzny | identity normalize ich nezliepa (frozen, minimal) |

## Akceptované limitácie

- **Image-only / fixed-layout knihy** (komiks, obrázková detská kniha) majú
  prázdny extracted text → všetky takéto knihy by mali rovnaký hash a
  kolidovali by. Pre textovú čítačku zameranú na klasickú literatúru je toto
  irelevantné (mimo cieľového use case), ale vedome to akceptujeme. Ak by sa
  to v budúcnosti stalo problémom, schemeVersion bumpneme a do hash-u
  zahrnieme aj manifest image binary digests.
- **Cross-edícia nie je cieľ.** Ten istý titul v dvoch rôznych vydaniach má
  rôzne hashe. Sync funguje len v rámci toho istého EPUB súboru — zhodne
  s ADR 0002 §4.3.
- **`package:html` ako dependency** je nutná pre P1 fix. Je to Dart team
  package, stabilná maintenance, žiadne realistické riziko že zmizne.

## Alternatívy zamietnuté (ostávajú z ADR 0003 + nové)

### SHA-256 celého ZIP súboru
Citlivé na ZIP metadata (timestamps, compression level, order entries).
Ten istý obsah v dvoch ZIP-och = rôzny hash = duplicitné knihy. Nevhodné.

### Hash celého obsahu vrátane metadata (pôvodný ADR 0003 návrh)
Metadata pridávajú krehkosť (typo fix) za nulový reálny rozlišovací zisk
(rozdiel medzi vydaniami je už v texte). Dropnuté po P3 review.

### Iterácia cez `book.Chapters` (pôvodný ADR 0003 návrh)
Vynechávalo `EpubChapter.SubChapters` → neúplný hash, ticho. Bug skrytý
testom „4 fixtures = 4 rôzne hashe" ktorý sa spoliehal len na top-level
rozdiely. Nahradené spine iteration po P2 review.

### Hand-roll regex tag-strip + ručný entity zoznam
Neúplný entity zoznam (chýbalo `&mdash;`, `&hellip;`, `&copy;`, numeric…)
by spôsobil že raz sa entita dekóduje a raz nie → nestabilný hash + zlý
extracted text. Nahradené `package:html` parser-om po P1 review.

### Coupling na `CanonicalChapterText` (M2.5, pôvodný ADR 0003 návrh)
Anchor normalize je živý kód ktorý sa vyvíja. Identity musí byť zamrznutá.
Decoupling cez vlastný `_identityNormalize` + scheme version je správna
voľba. Frozen rules sú jasne dokumentované.

### OCN / ISBN extrakcia z metadát
Project Gutenberg knihy nemajú ISBN. Nedeterministický fallback. Možný
sekundárny enrichment vo Fáze 4 ale primárna identita musí fungovať bez
neho.

### xxHash / Blake2 / BLAKE3
Rýchlejšie ale netreba — hash sa počíta raz pri importe knihy. SHA-256 je
štandard, všade dostupný, žiadne riziko že packaging zmizne.

### Cover image v hash-i
Cover sa môže meniť (publisher updates), text ostane rovnaký. Zahrnutie
covera by dalo „novú knihu" čo nie je správna sémantika.

## Dôsledky

- **M3 (Reader v1):** `Books` tabuľka môže dostať `contentHash TEXT` +
  `identitySchemeVersion INT` stĺpec. Dorátame pre existujúce knihy pri
  prvom otvorení po update.
- **Fáza 4 (Library++):** re-import deduplikácia sa postaví na `contentHash`.
- **Fáza 5 (sync):** anchor events nesú `(bookHash, schemeVersion)`.
  Sync vie že event z zariadenia A patrí knihe X iba ak na zariadení B
  existuje kniha s tým istým `(bookHash, schemeVersion)`. Bez toho sa anchor
  do resolve neposúva.
- **Bumpovanie schemeVersion v budúcnosti:** prebehne ako explicitná migrácia
  — pre každú knihu sa prepočíta nový hash, anchor records sa updatnú
  (`(bookHash_v1, 1) → (bookHash_v2, 2)`) na základe content match, nie
  ticho. Bez tejto explicit migration would orphan anchors.

## Mileniky implementácie (revízia)

| ID | Cieľ | Commit |
|----|------|--------|
| Spec v1 | `docs/specs/m2.6-book-identity.md` (pôvodný) | (M2.6 sequence) |
| T1 | crypto dep | M2.6 |
| T2 | `BookIdentity.compute` v1 | M2.6 |
| T3 | ADR 0003 | M2.6 |
| T4 | Merge do master | M2.6 |
| Review feedback | P1/P2/P3 + drobnosť | (this branch) |
| **Revision T1** | `html` dep | (pending) |
| **Revision T2** | `BookIdentity` rewrite + 10 testov | (pending) |
| **Revision T3** | This ADR + ADR 0003 superseded mark | (pending) |
| **Revision T4** | Spec update + merge do master | (pending) |
