import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/domain/anchor/anchor_codec.dart';

void main() {
  test('Test 6: normalize collapses mixed whitespace', () {
    const input = 'Hello \t\n world\n\nfoo';
    expect(AnchorCodec.normalize(input), 'Hello world foo');
  });

  test('normalize strips soft hyphens', () {
    const input = 'co­mpli­cated';
    expect(AnchorCodec.normalize(input), 'complicated');
  });

  test('normalize converts smart double quotes to straight', () {
    expect(AnchorCodec.normalize('“Do cats eat bats?”'), '"Do cats eat bats?"');
  });

  test('normalize converts smart single quotes / apostrophes', () {
    expect(AnchorCodec.normalize('it’s ‘nice’'), "it's 'nice'");
  });

  test('normalize converts em/en dashes to hyphen', () {
    expect(AnchorCodec.normalize('alpha—beta–gamma'), 'alpha-beta-gamma');
  });

  test('normalize converts horizontal ellipsis to three dots', () {
    expect(AnchorCodec.normalize('end…'), 'end...');
  });

  test('Test 5 (partial): normalize preserves diacritics', () {
    const input = 'è à ò š č ž';
    expect(AnchorCodec.normalize(input), 'è à ò š č ž');
  });

  test('normalize preserves case', () {
    expect(AnchorCodec.normalize('Hello World'), 'Hello World');
  });

  test('normalize trims edges', () {
    expect(AnchorCodec.normalize('  hi  '), 'hi');
  });
}
