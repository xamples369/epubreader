import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' show parse;

/// Deterministický content-based identifikátor knihy.
///
/// SHA-256 hex (64 znakov) z normalizovaného obsahu enumerovaného v poradí
/// spine (reading order, kompletné). Algoritmus je **zamrznutý pod
/// [schemeVersion]** — zmena akéhokoľvek kroku (parser, normalize, iteration)
/// musí bumpnúť scheme a riešiť ako migráciu.
///
/// Vstup pre SHA-256:
/// ```
/// SCHEME:<version>
/// ITEM:<href>:<frozen normalized text>
/// ITEM:<href>:<frozen normalized text>
/// ...
/// ```
///
/// Frozen normalizácia (`_identityNormalize`):
///   1. Parse HTML cez `package:html` (deterministická decode tagov +
///      všetkých named/numeric entít)
///   2. Extract `body.text` (alebo documentElement.text fallback)
///   3. Whitespace collapse (`\s+` → ` `)
///   4. Trim
///
/// **Žiadne** typografické reconciliations, soft hyphen stripping, ani NFC.
/// Tieto sú vlastnosti anchor matching-u (M2.5) ktorý sa môže vyvíjať
/// nezávisle. Identita je iná zodpovednosť — stabilita > flexibilita.
///
/// Detail: viď `docs/specs/m2.6-book-identity.md` a
/// `docs/adr/0004-book-identity-revised.md` (supersedes ADR 0003).
class BookIdentity {
  BookIdentity._();

  /// Verzia hash schémy. **Nikdy nemeň bez koordinovanej migrácie.**
  /// Bumpnutie tejto verzie invaliduje VŠETKY predtým spočítané hash-y.
  /// Anchory musia byť scope-ované na (bookHash, schemeVersion).
  static const int schemeVersion = 1;

  /// Vráti 64-char hex SHA-256 hash. Nikdy nevyhadzuje výnimku.
  static String compute(EpubBook book) {
    final input = _canonicalInput(book);
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString();
  }

  /// Public pre testovanie a diagnostiku — vráti raw input string ktorý sa
  /// hash-uje. Užitočné na overenie pokrytia (length sanity check).
  static String debugCanonicalInput(EpubBook book) => _canonicalInput(book);

  /// Diagnostic — pre každý spine item href vráti status mapovania:
  ///   - `'ok'` — lookup uspel, content má aj nejaký text po normalize
  ///   - `'empty-content'` — lookup uspel, ale source content je prázdny
  ///     (typicky cover wrapper s len obrázkom) — toto je legitímne
  ///   - `'lookup-failed'` — žiadny match v `book.Content.Html` alebo
  ///     ambiguous suffix match (vrátili sme null radšej než guess)
  ///
  /// Test môže asserovať že žiadny item nemá `lookup-failed`, ale
  /// `empty-content` toleruje (cover stránky, oddeľovače).
  static Map<String, String> debugResolveStatus(EpubBook book) {
    final result = <String, String>{};
    for (final href in _spineHrefs(book)) {
      final raw = _resolveHrefToHtml(book, href);
      if (raw == null) {
        result[href] = 'lookup-failed';
      } else if (_identityNormalize(raw).isEmpty) {
        result[href] = 'empty-content';
      } else {
        result[href] = 'ok';
      }
    }
    return result;
  }

  static String _canonicalInput(EpubBook book) {
    final parts = <String>['SCHEME:$schemeVersion'];

    final spineHrefs = _spineHrefs(book);
    for (final href in spineHrefs) {
      final raw = _resolveHrefToHtml(book, href) ?? '';
      final text = _identityNormalize(raw);
      parts.add('ITEM:$href:$text');
    }

    return parts.join('\n');
  }

  /// Spine iteration — kompletné poradie čítania, vrátane `linear="no"`
  /// itemov pre maximálnu deterministickú kompletnosť. Skipuje gracefully
  /// idref-y ktoré nemajú zhodu v manifest-e (malformed EPUB).
  static List<String> _spineHrefs(EpubBook book) {
    final spine = book.Schema?.Package?.Spine;
    final manifest = book.Schema?.Package?.Manifest;
    if (spine == null || manifest == null) return const [];

    final hrefById = <String, String>{};
    for (final item in manifest.Items ?? const <EpubManifestItem>[]) {
      final id = item.Id;
      final href = item.Href;
      if (id != null && href != null) {
        hrefById[id] = href;
      }
    }

    final result = <String>[];
    for (final ref in spine.Items ?? const <EpubSpineItemRef>[]) {
      final idRef = ref.IdRef;
      if (idRef == null) continue;
      final href = hrefById[idRef];
      if (href == null) continue; // malformed: skip
      result.add(href);
    }
    return result;
  }

  /// Resolve manifest href → raw HTML string z `book.Content.Html`.
  ///
  /// Manifest hrefs sú relatívne k OPF adresáru (`Text/ch1.xhtml`), kým
  /// `book.Content.Html` môže byť kľúčované plnou cestou od ZIP rootu
  /// (`OEBPS/Text/ch1.xhtml`).
  ///
  /// **Ranking by match strength** — pre frozen-forever schému je dôležité
  /// nehádať. Skúšame iba dve sily zhody a pri akejkoľvek ambiguite vrátime
  /// null (= „čestne prázdne") namiesto guess-u.
  ///
  /// Žiadny basename-only match — duplicitné basenames naprieč priečinkami
  /// sú v reálnych EPUB-och bežné (`part1/chapter.xhtml`,
  /// `part2/chapter.xhtml`) a basename match by ticho mapoval na zlý obsah.
  static String? _resolveHrefToHtml(EpubBook book, String href) {
    final htmlMap = book.Content?.Html;
    if (htmlMap == null) return null;

    // Strength 1 — exact match (najsilnejšie)
    final direct = htmlMap[href];
    if (direct != null) return direct.Content;

    // Strength 2 — suffix match (jeden alebo druhý smer). Musí byť unikátny.
    String? suffixHit;
    var suffixCount = 0;
    for (final entry in htmlMap.entries) {
      final key = entry.key;
      if (key.endsWith('/$href') || href.endsWith('/$key')) {
        suffixHit = entry.value.Content;
        suffixCount++;
        if (suffixCount > 1) return null; // ambiguous → honestly empty
      }
    }
    if (suffixCount == 1) return suffixHit;

    // Žiadna iná stratégia — basename match je príliš slabý
    // (`part1/chapter.xhtml` vs `part2/chapter.xhtml` by oba mapovali na
    // basename `chapter.xhtml`, čo je ticho zlé). Vrátime null.
    return null;
  }

  /// FROZEN identity normalization. **Nikdy nemeň bez bumpu schemeVersion.**
  ///
  /// Použitie deterministického XHTML parsera namiesto regex tag-stripu
  /// + ručného entity zoznamu — `package:html` dekóduje všetky named aj
  /// numeric entity (`&mdash;`, `&hellip;`, `&#160;`, `&#xA0;`, …)
  /// rovnako naprieč verziami a platformami.
  static String _identityNormalize(String htmlContent) {
    if (htmlContent.isEmpty) return '';
    final document = parse(htmlContent);
    final body = document.body ?? document.documentElement;
    final text = body?.text ?? '';
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.trim();
  }
}
