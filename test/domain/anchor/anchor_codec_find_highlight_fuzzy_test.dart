import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';

void main() {
  group('slidingFuzzyFind', () {
    test('Test 2: finds quote after 5-char insert in window', () {
      // Dlhší needle (120 znakov) aby 5 inserts bolo ~4% damage = sim ~0.96
      const original =
          'The quick brown fox jumps over the lazy dog repeatedly, and the cat watched from a high branch in the apple tree silently.';
      const modified =
          'Header. The quick brown FXXXXox jumps over the lazy dog repeatedly, and the cat watched from a high branch in the apple tree silently. Tail.';

      final result = AnchorCodec.slidingFuzzyFind(
        needle: original,
        haystack: modified,
        windowCenter: modified.indexOf('The'),
        windowRadius: 200,
      );

      expect(result, isNotNull);
      expect(result!.start, modified.indexOf('The'));
      expect((result.end - result.start - original.length).abs(),
          lessThanOrEqualTo(10));
    });

    test('Test 12: deletes also tolerated (sliding window)', () {
      const original =
          'The quick brown fox jumps over the lazy dog and the cat watched from a high branch in the apple tree above the garden silently.';
      // 'brown ' (6 chars) deleted from needle
      const modified =
          'Header. The quick fox jumps over the lazy dog and the cat watched from a high branch in the apple tree above the garden silently. Tail.';

      final result = AnchorCodec.slidingFuzzyFind(
        needle: original,
        haystack: modified,
        windowCenter: modified.indexOf('The'),
        windowRadius: 200,
      );

      expect(result, isNotNull);
      expect(result!.start, modified.indexOf('The'));
    });

    test('returns null when similarity below 0.92 threshold', () {
      const needle = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const haystack = 'completely different content zzzz';

      final result = AnchorCodec.slidingFuzzyFind(
        needle: needle,
        haystack: haystack,
        windowCenter: 10,
        windowRadius: 50,
      );

      expect(result, isNull);
    });

    test('empty needle returns null', () {
      final result = AnchorCodec.slidingFuzzyFind(
        needle: '',
        haystack: 'some text',
        windowCenter: 0,
      );
      expect(result, isNull);
    });

    test('empty haystack returns null', () {
      final result = AnchorCodec.slidingFuzzyFind(
        needle: 'some text',
        haystack: '',
        windowCenter: 0,
      );
      expect(result, isNull);
    });

    test('exact match in middle of window returns exact range', () {
      const needle = 'middle text';
      const haystack = 'aaa start text middle text more text end zzz';

      final result = AnchorCodec.slidingFuzzyFind(
        needle: needle,
        haystack: haystack,
        windowCenter: haystack.indexOf(needle),
        windowRadius: 50,
      );

      expect(result, isNotNull);
      expect(haystack.substring(result!.start, result.end), needle);
    });
  });
}
