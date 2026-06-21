import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/reading_position_anchor.dart';

void main() {
  test('Test 8: ReadingPositionAnchor JSON round-trip', () {
    const a = ReadingPositionAnchor(
      chapterId: 'OEBPS/Text/ch1.xhtml',
      charOffset: 5000,
      chapterLength: 12000,
    );
    final json = a.toJson();
    expect(json, {'c': 'OEBPS/Text/ch1.xhtml', 'o': 5000, 'n': 12000});

    final decoded = ReadingPositionAnchor.fromJson(json);
    expect(decoded, equals(a));
  });

  test('progress derived correctly', () {
    const a = ReadingPositionAnchor(
      chapterId: 'x',
      charOffset: 3000,
      chapterLength: 12000,
    );
    expect(a.progress, closeTo(0.25, 1e-9));
  });

  test('progress is 0.0 when chapterLength is 0 (defensive)', () {
    const a = ReadingPositionAnchor(
      chapterId: 'x',
      charOffset: 100,
      chapterLength: 0,
    );
    expect(a.progress, 0.0);
  });

  group('furthestRead merge', () {
    test('Test 9: chapter5@100 vs chapter3@9000 → chapter5 wins (spine first)',
        () {
      const a = ReadingPositionAnchor(
          chapterId: 'ch5', charOffset: 100, chapterLength: 10000);
      const b = ReadingPositionAnchor(
          chapterId: 'ch3', charOffset: 9000, chapterLength: 10000);

      const spineIndex = {'ch5': 5, 'ch3': 3};
      final winner = ReadingPositionAnchor.furthestRead(
          a, b, spineIndexOf: (id) => spineIndex[id] ?? -1);
      expect(winner.chapterId, 'ch5');
    });

    test('same chapter — higher charOffset wins', () {
      const a = ReadingPositionAnchor(
          chapterId: 'ch3', charOffset: 1000, chapterLength: 5000);
      const b = ReadingPositionAnchor(
          chapterId: 'ch3', charOffset: 4000, chapterLength: 5000);

      final winner =
          ReadingPositionAnchor.furthestRead(a, b, spineIndexOf: (_) => 3);
      expect(winner.charOffset, 4000);
    });

    test('unknown chapter id (spine -1) loses to known chapter', () {
      const a = ReadingPositionAnchor(
          chapterId: 'ch5', charOffset: 0, chapterLength: 100);
      const b = ReadingPositionAnchor(
          chapterId: 'unknown', charOffset: 9000, chapterLength: 10000);

      final winner = ReadingPositionAnchor.furthestRead(a, b,
          spineIndexOf: (id) => id == 'ch5' ? 5 : -1);
      expect(winner.chapterId, 'ch5');
    });

    test('identical anchors → returns first (deterministic)', () {
      const a = ReadingPositionAnchor(
          chapterId: 'x', charOffset: 100, chapterLength: 500);
      final winner =
          ReadingPositionAnchor.furthestRead(a, a, spineIndexOf: (_) => 0);
      expect(winner, a);
    });
  });
}
