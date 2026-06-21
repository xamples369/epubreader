import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;

class EpubMetadata {
  final String title;
  final String? author;
  final String? language;
  final Uint8List? coverBytes;

  const EpubMetadata({
    required this.title,
    required this.author,
    required this.language,
    required this.coverBytes,
  });
}

class EpubMetadataParser {
  static Future<EpubMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    final title = (book.Title?.isNotEmpty ?? false)
        ? book.Title!
        : file.uri.pathSegments.last;

    final author = (book.AuthorList?.isNotEmpty ?? false)
        ? book.AuthorList!.first
        : book.Author;

    String? language;
    final langs = book.Schema?.Package?.Metadata?.Languages;
    if (langs != null) {
      for (final l in langs) {
        if (l.isNotEmpty) {
          language = l;
          break;
        }
      }
    }

    Uint8List? coverBytes;
    final coverImage = book.CoverImage;
    if (coverImage != null) {
      coverBytes = Uint8List.fromList(img.encodePng(coverImage));
    }

    return EpubMetadata(
      title: title,
      author: author,
      language: language,
      coverBytes: coverBytes,
    );
  }
}
