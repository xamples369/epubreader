import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:epubreader/data/storage/cover_storage.dart';

void main() {
  late Directory tmp;
  late CoverStorage storage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cover_storage_test_');
    storage = CoverStorage(baseDir: tmp);
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Windows may briefly lock files; ignore.
    }
  });

  test('store writes png and returns absolute path', () async {
    final bytes = Uint8List.fromList(List<int>.generate(200, (i) => i));
    final path = await storage.store('book-1', bytes);

    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync(), bytes);
    expect(path.endsWith('book-1.png'), isTrue);
  });

  test('store overwrites existing cover for same id', () async {
    await storage.store('b', Uint8List.fromList([1, 2, 3]));
    await storage.store('b', Uint8List.fromList([4, 5, 6]));
    final path = storage.pathFor('b');
    expect(File(path).readAsBytesSync(), [4, 5, 6]);
  });
}
