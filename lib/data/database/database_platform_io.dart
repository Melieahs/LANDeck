import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openPlatformDatabase({required int version}) async {
  final Directory directory = await getApplicationSupportDirectory();
  final String path = p.join(directory.path, 'landeck.db');
  return databaseFactoryIo.openDatabase(
    path,
    version: version,
    onVersionChanged: (Database db, int oldVersion, int newVersion) async {
      // Data migration is idempotent and runs in AppDatabase.open().
    },
  );
}
