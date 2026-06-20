// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EPUB Reader';

  @override
  String get libraryEmpty => 'Your library is empty. Add your first book.';

  @override
  String get addBook => 'Add book';

  @override
  String get libraryTitle => 'Library';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewList => 'List';

  @override
  String get readerStubTitle => 'Reader (coming soon)';

  @override
  String get readerStubBody =>
      'This is a placeholder. Real reading lands in M3.';

  @override
  String get errorOpenEpub => 'Could not open EPUB file.';

  @override
  String get unknownAuthor => 'Unknown author';
}
