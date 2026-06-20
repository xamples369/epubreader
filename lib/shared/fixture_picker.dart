import 'package:file_picker/file_picker.dart';

/// Návratový typ — buď cesta k vybranému súboru, alebo null ak používateľ
/// dialog zrušil.
Future<String?> pickEpubFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
    allowMultiple: false,
    dialogTitle: 'Vyber EPUB súbor',
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }
  return result.files.first.path;
}
