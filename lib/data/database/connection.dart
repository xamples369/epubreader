import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Otvorí lokálnu SQLite databázu v platform-specific app data dir.
AppDatabase openAppDatabase() {
  return AppDatabase(driftDatabase(name: 'epubreader'));
}
