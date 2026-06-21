import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class CoverStorage {
  final Directory baseDir;

  CoverStorage({required this.baseDir});

  static Future<CoverStorage> system() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/EpubReader/covers');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return CoverStorage(baseDir: dir);
  }

  String pathFor(String bookId) => '${baseDir.path}/$bookId.png';

  Future<String> store(String bookId, Uint8List bytes) async {
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    final path = pathFor(bookId);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
