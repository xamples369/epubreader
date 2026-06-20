// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class AppLocalizationsSk extends AppLocalizations {
  AppLocalizationsSk([String locale = 'sk']) : super(locale);

  @override
  String get appTitle => 'EPUB Reader';

  @override
  String get libraryEmpty => 'Knižnica je prázdna. Pridaj prvú knihu.';

  @override
  String get addBook => 'Pridať knihu';

  @override
  String get libraryTitle => 'Knižnica';

  @override
  String get viewGrid => 'Mriežka';

  @override
  String get viewList => 'Zoznam';

  @override
  String get readerStubTitle => 'Reader (v príprave)';

  @override
  String get readerStubBody =>
      'Toto je dočasná obrazovka. Reálne čítanie príde v M3.';

  @override
  String get errorOpenEpub => 'Nepodarilo sa otvoriť EPUB súbor.';

  @override
  String get unknownAuthor => 'Neznámy autor';
}
