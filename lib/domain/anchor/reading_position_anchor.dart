import 'package:meta/meta.dart';

/// Render-agnostický anchor pre „kde som skončil v knihe".
/// `charOffset` je pozícia v normalizovanom texte kapitoly (cez
/// `CanonicalChapterText.extract`), nezávislá od fontu/marginov/zariadenia.
@immutable
class ReadingPositionAnchor {
  final String chapterId; // manifest href alebo "#<spineIndex>"
  final int charOffset; // offset v NORMALIZED texte kapitoly
  final int chapterLength; // dĺžka NORMALIZED textu (pre offline UI %)

  const ReadingPositionAnchor({
    required this.chapterId,
    required this.charOffset,
    required this.chapterLength,
  });

  /// 0.0 – 1.0 zlomok kapitoly. Defensive: vracia 0.0 ak chapterLength == 0.
  double get progress =>
      chapterLength == 0 ? 0.0 : charOffset / chapterLength;

  Map<String, dynamic> toJson() => {
        'c': chapterId,
        'o': charOffset,
        'n': chapterLength,
      };

  factory ReadingPositionAnchor.fromJson(Map<String, dynamic> json) =>
      ReadingPositionAnchor(
        chapterId: json['c'] as String,
        charOffset: (json['o'] as num).toInt(),
        chapterLength: (json['n'] as num).toInt(),
      );

  /// Vyberie z dvoch anchorov ten ktorý je „furthest read" — najprv podľa spine
  /// indexu kapitoly, potom podľa charOffset v kapitole. Pri rovnosti vracia
  /// prvý parameter (deterministicky).
  ///
  /// `spineIndexOf` je callback ktorý vráti spine index pre chapterId v
  /// aktuálnej knihe; spine index je vlastnosť súboru, nie anchoru, preto sa
  /// neukladá v anchore samotnom.
  static ReadingPositionAnchor furthestRead(
    ReadingPositionAnchor a,
    ReadingPositionAnchor b, {
    required int Function(String chapterId) spineIndexOf,
  }) {
    final spineA = spineIndexOf(a.chapterId);
    final spineB = spineIndexOf(b.chapterId);

    if (spineA != spineB) {
      return spineA > spineB ? a : b;
    }
    if (a.charOffset != b.charOffset) {
      return a.charOffset > b.charOffset ? a : b;
    }
    return a;
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingPositionAnchor &&
      other.chapterId == chapterId &&
      other.charOffset == charOffset &&
      other.chapterLength == chapterLength;

  @override
  int get hashCode => Object.hash(chapterId, charOffset, chapterLength);
}
