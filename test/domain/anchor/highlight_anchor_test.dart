import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/highlight_anchor.dart';

void main() {
  test('HighlightAnchor JSON round-trip with charOffset', () {
    const a = HighlightAnchor(
      chapterId: 'OEBPS/ch3.xhtml',
      quote: 'Down, down, down.',
      prefix: 'Alice began ',
      suffix: ' Would the fall',
      charOffset: 1247,
    );
    final json = a.toJson();
    expect(json, {
      'c': 'OEBPS/ch3.xhtml',
      'q': 'Down, down, down.',
      'pre': 'Alice began ',
      'suf': ' Would the fall',
      'o': 1247,
    });

    final decoded = HighlightAnchor.fromJson(json);
    expect(decoded, equals(a));
  });

  test('HighlightAnchor JSON round-trip with null charOffset', () {
    const a = HighlightAnchor(
      chapterId: 'x',
      quote: 'q',
      prefix: 'p',
      suffix: 's',
      charOffset: null,
    );
    final json = a.toJson();
    expect(json.containsKey('o'), isFalse);

    final decoded = HighlightAnchor.fromJson(json);
    expect(decoded.charOffset, isNull);
    expect(decoded, equals(a));
  });
}
