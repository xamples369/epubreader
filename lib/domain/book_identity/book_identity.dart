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
  /// (`OEBPS/Text/ch1.xhtml`). Skúšame viac variantov mapovania.
  static String? _resolveHrefToHtml(EpubBook book, String href) {
    final htmlMap = book.Content?.Html;
    if (htmlMap == null) return null;

    // Try direct match
    final direct = htmlMap[href];
    if (direct != null) return direct.Content;

    // Try suffix / prefix matches (handle OPF-relative vs root-relative)
    final hrefBasename = _basename(href);
    for (final entry in htmlMap.entries) {
      final key = entry.key;
      if (key == href ||
          key.endsWith('/$href') ||
          href.endsWith('/$key') ||
          _basename(key) == hrefBasename) {
        return entry.value.Content;
      }
    }
    return null;
  }

  static String _basename(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
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
