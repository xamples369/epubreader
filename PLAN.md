# EPUB Reader — Plán projektu

> Multiplatformový EPUB čítač (Windows + Android) bez reklám,
> s premium funkciami a synchronizáciou cez používateľov vlastný cloud.

---

## Vízia

Vlastný spoľahlivý EPUB reader, ktorý:
- beží na PC aj mobile z jedného kódu,
- nemá reklamy ani „upgrade na premium" hlášky,
- má kvalitné vykresľovanie textu a komfortné nastavenia čítania,
- synchronizuje pozíciu/záložky/poznámky cez cloud, ktorý si používateľ sám zvolí
  (Google Drive / OneDrive / Dropbox / WebDAV / lokálny priečinok),
- je rozšíriteľný — postupne pridávame funkcie po fázach.

---

## Technológia (predbežne)

- **Flutter + Dart** — jeden codebase pre Windows + Android (neskôr prípadne iOS/macOS/Linux)
- **Riverpod** — state management
- **Drift (SQLite)** — lokálna databáza (knižnica, anotácie, pozícia čítania)
- **EPUB knižnica** — vybrať počas Fázy 1 z kandidátov: `epub_view`, `epubx`, `flutter_epub_viewer`
- **Cloud abstrakcia** — vlastné rozhranie + pluginy pre jednotlivých providerov

> Tieto voľby ešte nie sú zabetónované, finalizujeme ich pred Fázou 1.

---

## Fázy

Každá fáza dostane vlastný **spec** v `docs/specs/` a **implementačný plán**.
Najprv brainstorm → spec → plán → kód → review → ďalšia fáza.

### Fáza 1 — MVP „Čítačka" 🔜
Cieľ: minimálna použiteľná appka, ktorou sa dá reálne čítať kniha.

- [ ] Výber a otestovanie EPUB renderovacej knižnice
- [ ] Otvorenie EPUB súboru z disku
- [ ] Listovanie/scrollovanie textu
- [ ] Jednoduchá knižnica (zoznam kníh + obálky)
- [ ] Téma pozadia (svetlá / sépia / čierna)
- [ ] Veľkosť písma + výber fontu
- [ ] Build pre Windows
- [ ] Build pre Android
- [ ] Spec: `docs/specs/phase-1-mvp.md`

### Fáza 2 — Navigácia v knihe
- [ ] Obsah (TOC) + skok na kapitolu
- [ ] Záložky (pridať / zoznam / skok)
- [ ] Vyhľadávanie v knihe (full-text)
- [ ] Indikátor pokroku (% a čas do konca kapitoly)
- [ ] Spec: `docs/specs/phase-2-navigation.md`

### Fáza 3 — Anotácie
- [ ] Zvýrazňovanie textu vo viacerých farbách
- [ ] Poznámky priviazané k zvýrazneniam
- [ ] Zoznam anotácií v knihe + export
- [ ] Spec: `docs/specs/phase-3-annotations.md`

### Fáza 4 — Knižnica++
- [ ] Metadata (autor, žáner, hodnotenie, tagy)
- [ ] Kolekcie/police („rozčítané", „prečítané", vlastné)
- [ ] Triedenie a filtrovanie
- [ ] Import obálok ak chýbajú
- [ ] Spec: `docs/specs/phase-4-library.md`

### Fáza 5 — Cloud sync
- [ ] Plugin architektúra pre cloud providerov
- [ ] Provider: Google Drive
- [ ] Provider: OneDrive
- [ ] Provider: Dropbox
- [ ] Provider: WebDAV
- [ ] Provider: lokálny priečinok / sieťový disk
- [ ] Sync metadát (pozícia, záložky, anotácie)
- [ ] Voliteľne sync samotných EPUB súborov
- [ ] Riešenie konfliktov
- [ ] Spec: `docs/specs/phase-5-cloud-sync.md`

### Fáza 6 — Premium UX
- [ ] Slovník (klik na slovo → preklad/definícia)
- [ ] Štatistiky čítania (séria dní, prečítané strany, rýchlosť)
- [ ] Plynulé scrollovanie vs. stránkovanie (prepínateľné)
- [ ] Nočný režim s reguláciou jasu
- [ ] Vlastné farby a kustomizácia
- [ ] Spec: `docs/specs/phase-6-premium-ux.md`

---

## Aktuálny stav

**Fáza:** Brainstorming Fázy 1 (MVP)
**Posledná aktualizácia:** 2026-06-19

### Hotové
- [x] Rozhodnutie: Flutter (PC + Android, jeden codebase)
- [x] Rozhodnutie: cloud sync cez používateľov vlastný účet, plugin architektúra
- [x] Rozdelenie projektu na 6 fáz
- [x] Inicializácia repozitára + tento plán

### Najbližší krok
- Detailný brainstorm Fázy 1 (MVP) → spec → implementačný plán

---

## Ako pracujeme

1. Pre každú fázu najprv **brainstormujeme** (otázky a odpovede),
2. potom napíšem **spec** do `docs/specs/`,
3. ty ho **odsúhlasíš** alebo dáš pripomienky,
4. vytvorím **implementačný plán** s konkrétnymi krokmi,
5. **kódime** po malých kúskoch s priebežným testovaním,
6. zaškrtneme hotové úlohy v tomto `PLAN.md`,
7. ideme na ďalšiu fázu.
