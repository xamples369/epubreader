import 'package:meta/meta.dart';

/// Render-agnostický anchor pre highlight (text snippet s kontextom).
/// Postavený na W3C TextQuoteSelector-like dizajne: `quote` identifikuje text,
/// `prefix`/`suffix` slúžia na disambiguáciu pri viacerých výskytoch,
/// `charOffset` je len optional hint na zrýchlenie resolve search-u.
@immutable
class HighlightAnchor {
  final String chapterId; // manifest href alebo "#<spineIndex>"
  final String quote; // max 200 znakov (cap-nuté v createHighlight)
  final String prefix; // max 32 znakov pred quote
  final String suffix; // max 32 znakov za quote
  final int? charOffset; // hint, môže byť null ak text nebol nájdený pri tvorbe

  const HighlightAnchor({
    required this.chapterId,
    required this.quote,
    required this.prefix,
    required this.suffix,
    required this.charOffset,
  });

  Map<String, dynamic> toJson() {
    final j = <String, dynamic>{
      'c': chapterId,
      'q': quote,
      'pre': prefix,
      'suf': suffix,
    };
    if (charOffset != null) j['o'] = charOffset;
    return j;
  }

  factory HighlightAnchor.fromJson(Map<String, dynamic> json) =>
      HighlightAnchor(
        chapterId: json['c'] as String,
        quote: json['q'] as String,
        prefix: json['pre'] as String,
        suffix: json['suf'] as String,
        charOffset: json.containsKey('o') ? (json['o'] as num).toInt() : null,
      );

  @override
  bool operator ==(Object other) =>
      other is HighlightAnchor &&
      other.chapterId == chapterId &&
      other.quote == quote &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.charOffset == charOffset;

  @override
  int get hashCode =>
      Object.hash(chapterId, quote, prefix, suffix, charOffset);
}
