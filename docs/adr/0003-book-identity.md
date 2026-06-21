# ADR 0003 — Book Identity

**Status:** Accepted
**Dátum:** 2026-06-21
**Kontext:** M2.6, Fáza 1 (MVP)
**Supersedes:** —
**Related:** ADR 0002 (anchor format), `docs/specs/m2.6-book-identity.md`,
`docs/strategy/2026-06-21-renderer-anchor-sync-analysis.md` §5

---

## Kontext

ADR 0002 (anchor) explicitne obmedzuje: *„anchor sa resolve-uje len v EPUB
súbore s rovnakým content hash-om"*. M2.6 ten content hash dodáva ako
konkrétny algoritmus.

Bez book-identity nemá zmysel cross-device sync (Fáza 5) — zariadenie A
nevie že „Alice" na ňom je tá istá kniha ako „Alice" na zariadení B, ak by
súbory mali iný hash (rôzny ZIP timestamp).

## Rozhodnutie

**Algoritmus:** SHA-256 hex (64 znakov, lowercase, `[0-9a-f]+`).

**Vstup:** UTF-8 enkódovanie kanonického reťazca:

```
TITLE:<lowercase trimmed title>
AUTHORS:<auth1>|<auth2>|...
LANG:<primary language or empty>
CHAPTER:<chapterId1>:<canonical text of chapter 1>
CHAPTER:<chapterId2>:<canonical text of chapter 2>
...
```

Kanonický text kapitol pochádza z **`CanonicalChapterText.extract`** (M2.5,
ADR 0002) — single source of truth pre normalizáciu obsahu naprieč anchor
formátom aj book identity. To znamená že obe vrstvy reagujú konzistentne na
to isté typografické / whitespace normalizovanie.

**API:** `BookIdentity.compute(EpubBook) → String` v `lib/domain/book_identity/`.
Statická metóda, nikdy nevyhadzuje výnimku.

## Reálne hash-y z fixtures (verifikácia)

Spočítané `BookIdentity.compute` nad `test/fixtures/`:

| Fixture | SHA-256 |
|---------|---------|
| alice.epub | `6c4ac9f209c957227f0243306b53ad6fe314db07f7529d04ccd2e043d9e7e3ff` |
| pride.epub | `e4f0464f59e70ad2772dbe58306eff6d83aa2d7e978456a0af6796dc556aa0ff` |
| frankenstein.epub | `811b6ed26138d177015e05303dc44fe8e0b0ba854134df42f49b7d7630c5865c` |
| divina.epub | `969d8a10bdfdaced852b3bf9528efec8f677cc1ab95fb3a192c17338664ab3f7` |

Štyri rôzne knihy → štyri rôzne hash-y. Žiadne kolízie. (Trivial test, ale
dáva istotu že implementácia funguje.)

## Stabilita

| Scenár | Hash | Pozn. |
|--------|------|-------|
| Rovnaký súbor, dvakrát načítaný | rovnaký | testované |
| Rovnaký obsah v novom ZIP (iný compression / timestamps) | rovnaký | hash ignoruje ZIP metadata, čerpá z OPF + chapter HTMLs |
| Iné vydanie tej istej knihy (iný preklad, doplnené kapitoly) | rôzny | rôzne metadáta + rôzny text |
| Drobné editácie textu (oprava preklepu) | rôzny | hash je content-sensitive — chápeme to ako iné vydanie |
| Zmenená obálka, rovnaký text + metadata | **rovnaký** | cover nie je v hash-i (akceptovaná limitácia — cover nepatrí do čítacieho obsahu) |

## Dôsledky

- **M3 (Reader v1)**: keď bude potreba dohľadávať aké RP záznamy patria
  k otvorenej knihe, môže `Books` tabuľka dostať `contentHash` stĺpec.
  Migration triviálna — dorátame pre existujúce knihy pri prvom otvorení
  po update.
- **Fáza 4 (Library++)**: re-import deduplikácia (`„už máš túto knihu"`
  dialóg) sa dá postaviť nad týmto hash-om.
- **Fáza 5 (sync)**: anchor events nesú `bookHash` — sync vie že event z
  zariadenia A patrí knihe X len ak na zariadení B existuje kniha s tým
  istým hash-om. Bez toho by sa anchor mohol pokúsiť resolvnúť proti
  inej (nepriraditeľnej) knihe.

## Alternatívy zamietnuté

### SHA-256 celého ZIP súboru
Najjednoduchšie, ale citlivé na ZIP metadata (timestamps, compression level,
poradie entries). Ten istý obsah v dvoch rôznych ZIP-och = rôzny hash =
duplicitné knihy v knižnici. Nevhodné pre cieľ stability cez sync.

### Hash len kanonického textu (bez metadata)
Sympatické pre maximálnu stabilitu, ale stratíme schopnosť rozlíšiť dva
legitímne rôzne titule s rovnakým textovým obsahom — napr. ak vydavateľ
vydá novú edíciu s pridaným predhovorom a novou obálkou pri rovnakom hlavnom
texte, používateľ to vníma ako inú knihu (chce vlastnú pozíciu čítania,
vlastné poznámky). Hash s metadata to rieši.

### OCN / ISBN extrakcia z EPUB metadát
Project Gutenberg knihy nemajú ISBN. Vlastné/staršie EPUB knihy taktiež
často nie. ISBN je nedeterministický fallback — odkladáme na možné
sekundárne enrichment (Fáza 4 metadata correction), ale primárna identita
musí fungovať aj bez neho.

### xxHash / Blake2 / BLAKE3
Rýchlejšie ako SHA-256, ale netreba rýchlosť — hash sa počíta raz pri
importe knihy, nie v hot path. SHA-256 je všade dostupný (`package:crypto`),
štandard, žiadne riziko že packaging zmizne. Konzervatívna voľba.

### Cover image v hash-i
Cover sa môže meniť (publisher updates, alebo používateľ vymení), ale text
ostane rovnaký. Ak by sme cover zahrnuli do hash-u, zmena obálky by dala
„novú knihu" čo nie je správna sémantika. Cover je vizuálna metadáta,
nie čítací obsah.

## Mileniky implementácie

| ID | Cieľ | Commit |
|----|------|--------|
| Spec | `docs/specs/m2.6-book-identity.md` | (spec commit) |
| T1 | Pridať crypto dep + scaffold | (ee2e120 + scaffold) |
| T2 | `BookIdentity.compute` + 7 testov | (ec2accc) |
| T3 | This ADR + cleanup helper | (pending) |
| T4 | Merge do master | (pending) |

## Testy

`test/domain/book_identity/book_identity_test.dart` — 7 testov:
determinizmus, formát (64-char hex), unikátnosť 4 fixtures, stabilita
re-load, edge no chapters, edge no metadata, rôzne tituly → rôzne hash-y.
Všetky pass.
