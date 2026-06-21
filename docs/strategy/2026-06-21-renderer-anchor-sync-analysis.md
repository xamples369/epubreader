# EPUB Reader — zhrnutie analýzy a odporúčania

> Poznámky k projektu `xamples369/epubreader` (Flutter, multiplatform, sync cez vlastný cloud používateľa).
> Vzniklo z diskusie o konkurencii, sync modeli a voľbe rendereru.

---

## 1. Kontext a pozícia produktu

Staviaš multiplatformovú (Windows + Android) EPUB čítačku bez reklám, s prémiovými
funkciami a synchronizáciou cez cloud, ktorý si zvolí sám používateľ.

**Konkurenčná realita:** väčšina „prémiových" funkcií je dnes zadarmo už inde —
hĺbková customizácia (Moon+ Reader), EPUB 3 + OPDS + DRM (Thorium), TTS a cloud
(PocketBook, Freda), správa knižnice (Calibre). Čistý čítací engine + bežné prémiové
funkcie sú teda komoditizované.

**Kde je reálny priestor odlíšiť sa:**

- **Sync je tá jediná funkcia, za ktorú ľudia naozaj platia.** Highlighty aj TTS majú
  zadarmo všade; udržať pozíciu, poznámky a knižnicu v zhode naprieč zariadeniami je to,
  čo konkurencia spoplatňuje. Tvoja voľba — sync cez vlastný cloud používateľa — to rieši
  pri takmer nulových marginálnych nákladoch a dáva silný privacy argument, ktorý
  Google Play Books nemá (dáta ostávajú u používateľa, ty nie si ich správca → menej GDPR bremena).
- **Export a ďalší život poznámok.** Existujúce riešenia sú najslabšie práve v tom, čo sa
  stane s highlightmi *potom*: slabý export, žiadne prepojenie na knowledge management.
  Prepojenie na Obsidian / Notion / Anki + poriadny export je najsilnejší diferenciátor.

---

## 2. NAJVÄČŠIE RIZIKO — voľba rendereru ↔ kotvenie pre sync

Toto nie je problém Fázy 5 (cloud). Je zabetónované už vo Fáze 1, v ADR 0001 o rendereri —
a je vážne práve preto, že celý produkt staviaš na cross-device syncu.

### Problém

`epub_view` (zvolený, v3.2.0) renderuje cez **Flutter widgety, nie natívny view**
(parser `epub` + `flutter_html`). Dôsledky:

1. **Nižšia vernosť vykresľovania** — `flutter_html` nikdy nedosiahne reálny prehliadačový
   engine. Komplexné publisher CSS, fixed-layout a jemná typografia budú degradovať.
   To ide proti vízii „kvalitné vykresľovanie textu".
2. **Skrytý, horší problém — ako reprezentuješ kotvu?** Pri widget-renderingu prirodzene
   vyjde ukladať pozíciu ako index odseku alebo scroll offset. To je závislé od zariadenia,
   veľkosti písma a konkrétneho renderu. Na inom zariadení / po zmene fontu ukazuje inam.
   Pri highlightoch je to fatálne — kotva na widget index sa po reflow rozsype.
   A pritom celý zmysel appky je: vyznačím vetu na telefóne → nájdem ju na PC.

### Štandardné riešenie

**CFI (Canonical Fragment Identifier)** — reflow-nezávislá kotva do EPUB-u, ktorú používa
Readium, Apple Books aj Kobo. Irónia: zavrhnutý `flutter_epub_viewer` (Epub.js +
`flutter_inappwebview`) CFI podporuje priamo — reading progress aj výber textu vracia ako CFI,
plus vernejší rendering cez reálny engine. Cena: čítacia plocha je HTML/JS namiesto Flutter
widgetov, ťažšia hĺbková customizácia z Dartu, a na Windows beží cez WebView2 (možno dôvod
toho „padol pri renderingu" — môže byť fixnuteľný setup, alebo reálny blocker).

### Odporúčanie

**Over si TERAZ, kým si vo Fáze 1**, jednu vec: vie mi `epub_view` dať stabilný,
reflow-nezávislý, naprieč zariadeniami prenositeľný lokátor? Podľa odpovede:

- **Ak áno** → postav kotvu nad ním a pokračuj.
- **Ak nie** → buď prehodnoť WebView renderer (a vyrieš Windows rendering bug), **alebo**
  si zadefinuj **vlastnú render-agnostickú kotvu**:
  `(id súboru kapitoly + normalizovaný citát textu + znakový offset)`
  — v podstate W3C Annotation `TextQuoteSelector` / Readium locator. Kotvu po načítaní knihy
  znova *nájdeš podľa textu*, nie podľa pozície vo widgetoch → prežije reflow aj zmenu zariadenia.
  Viac práce, ale navždy ťa to oslobodí od toho, ako presne kreslíš stránku.

---

## 3. Dátový model anotácií a sync (rozhodnúť PRED Fázou 3)

Tvoje fázy oddeľujú anotácie (Fáza 3) od syncu (Fáza 5), ale **schéma v Drift, ktorú napíšeš
pre anotácie, rozhodne o tom, či bude sync hladký alebo prepis.**

### Pasce, ktorým sa treba vyhnúť

- **Naivné „posledný zápis vyhráva"** ti potichu zožerie poznámky pri offline editácii na
  viacerých zariadeniach.
- **Sync jedného zdieľaného súboru** (napr. jedna SQLite DB) cez cloud → keď doň zapíšu dve
  zariadenia, máš poškodený súbor.

### Robustný vzor

- Knihy ako súbory; **anotácie a pozíciu drž ako append-only event log** (žurnál udalostí).
- **Jeden súbor per zariadenie**, žiadni dvaja klienti nezapisujú do toho istého → žiadne
  konflikty na úrovni storage.
- Pri čítaní logy **deterministicky zlúčiš** vo svojej logike.
- Kotva v evente musí byť tá render-agnostická z bodu 2.
- (Ambicióznejšie, na neskôr: CRDT na anotácie. Na začiatok stačí event log.)

> Ak anotácie uložíš ako meniteľné riadky s widget-indexovou kotvou → vo Fáze 5 ťa čaká
> migrácia DB **aj** prepis merge logiky. Ak ich od začiatku uložíš ako event log s
> render-agnostickou kotvou → Fáza 5 je už len doprava tých eventov cez cloud.

---

## 4. Cloud integrácia — praktické poznámky (Fáza 5)

- **Nepíš desať integrácií.** WebDAV jedným backendom pokryje Nextcloud aj veľa selfhosterov.
- **Dropbox a Google Drive** majú slušné **delta / changes API** — pýtaj sa len na zmeny,
  nesťahuj všetko dookola.
- **iCloud** nechaj nakoniec alebo úplne vynechaj — zamknuté na Apple, bolestivý background
  sync, zlý pomer práca/úžitok. (Už ho v pláne nemáš — dobre.)
- **Polling vs. push:** väčšina spotrebiteľských API nedá poriadne notifikácie → počítaj
  s rozumným pollingom cez delta API.
- **OAuth je friction.** „Pripoj si svoj Drive" je viac obrazoviek a časť ľudí tam odpadne.
  Sprav to čo najhladšie a maj **režim „skús to bez syncu"**, nech prvý zážitok nie je o setupe.

---

## 5. Book identity (predpoklad pre cross-device sync)

Ako dve zariadenia rozhodnú, že ide o **tú istú** knihu, keď súbor môže mať inú veľkosť či
hash a ISBN v EPUB-e často chýba? Väčšinou: **hash obsahu alebo normalizovaný identifikátor**.
Táto logika je predpoklad pre to, aby si vedel priradiť kotvy správnej knihe — bez nej
sa highlighty z jedného zariadenia nemajú k čomu priviazať na druhom.

---

## 6. Drobnosti

- **C++ 54,7 % v repe nie je tvoj kód** — je to Flutter Windows runner (CMake + desktop
  embedder), úplne normálne. Tvoj reálny kód je ten Dart.
- **Proces (brainstorm → spec → ADR → plán → kód → review) je na sólo projekt nadpriemerný.**
  Drž sa ho.

---

## 7. Odporúčané ďalšie kroky (podľa priority)

1. **[done — ADR 0002]** Over kotvenie v `epub_view`.
   *Výsledok:* paragraph-index scroll + bonus CFI cez `generateEpubCfi()` /
   `gotoEpubCfi()`. Char→paragraph mapping pre Plán A v M3.
2. **[done — ADR 0002]** Render-agnostická kotva = vlastný TextQuoteSelector-style
   nad single source of truth (`CanonicalChapterText` cez epubx). Sliding fuzzy
   resolve, typographic punctuation reconciliation.
3. **Navrhni Drift schému anotácií ako event log** s tou kotvou — ešte pred implementáciou Fázy 3.
   *Polia explicitne uvedené v ADR 0002 §8.*
4. **Definuj book-identity** (hash obsahu / normalizovaný id) — ešte pred Fázou 4/5.
   *ADR 0003 — odporúčaná M2.6.*
5. Pokračuj v MVP (Fáza 1–2), ale s vedomím, že kroky 2–4 sú už zafixované v dátovom modeli.
6. Neskôr: export anotácií + prepojenie na Obsidian/Notion/Anki ako hlavný diferenciátor.

---

*Posledná aktualizácia: 2026-06-21*
