import 'package:sembast_web/sembast_web.dart';

Future<Database> openPlatformDatabase({required int version}) {
  // IndexedDB name, not a file path.
  return databaseFactoryWeb.openDatabase(
    'landeck.db',
    version: version,
    onVersionChanged: (Database db, int oldVersion, int newVersion) async {
      // Data migration is idempotent and runs in AppDatabase.open().
    },
  );
}
