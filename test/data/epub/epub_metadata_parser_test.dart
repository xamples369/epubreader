import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/epub/epub_metadata_parser.dart';

void main() {
  test('alice.epub parses title, author, cover bytes', () async {
    final file = File('test/fixtures/alice.epub');
    expect(file.existsSync(), isTrue, reason: 'fixture missing');

    final meta = await EpubMetadataParser.parse(file);

    expect(meta.title, contains('Alice'));
    expect(meta.author, isNotNull);
    expect(meta.coverBytes, isNotNull);
    expect(meta.coverBytes!.length, greaterThan(100));
  });

  test('divina.epub has Dante as author', () async {
    final file = File('test/fixtures/divina.epub');
    final meta = await EpubMetadataParser.parse(file);

    expect(meta.title, isNotEmpty);
    expect(meta.author, contains('Dante'));
  });

  test('parse throws on invalid file', () async {
    final tmp = File('${Directory.systemTemp.path}/not-an-epub.epub');
    await tmp.writeAsString('not really an epub');
    try {
      await expectLater(
        EpubMetadataParser.parse(tmp),
        throwsA(isA<Object>()),
      );
    } finally {
      try {
        await tmp.delete();
      } catch (_) {
        // Windows can briefly lock the file; ignore.
      }
    }
  });
}
