import 'package:meta/meta.dart';

/// Vlastná typovo-bezpečná trieda — neviažeme sa na Flutter dart:ui.TextRange,
/// aby domain vrstva neimportovala Flutter.
@immutable
class AnchorRange {
  final int start; // character offset v normalised texte kapitoly
  final int end;
  const AnchorRange(this.start, this.end);

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is AnchorRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'AnchorRange($start, $end)';
}
