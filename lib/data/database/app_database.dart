import 'package:sembast/sembast.dart';

import 'database_migration.dart';
import 'database_platform_io.dart'
    if (dart.library.html) 'database_platform_web.dart';

/// On-device persistence for services and devices.
///
/// Sembast stores JSON-like records in a single local database file on
/// Android. No demo records are seeded: a fresh install opens an empty database.
class AppDatabase {
  AppDatabase._(this.db);

  static const int schemaVersion = 2;

  final Database db;

  static final StoreRef<String, Map<String, Object?>> serviceStore =
      StoreRef<String, Map<String, Object?>>('services');
  static final StoreRef<String, Map<String, Object?>> deviceStore =
      StoreRef<String, Map<String, Object?>>('devices');
  static final StoreRef<String, Map<String, Object?>> metaStore =
      StoreRef<String, Map<String, Object?>>('meta');

  static Future<AppDatabase> open() async {
    final Database db = await openPlatformDatabase(version: schemaVersion);
    await migrateDatabase(db);
    return AppDatabase._(db);
  }

  /// Used by tests with a memory or temporary database.
  static Future<AppDatabase> openFromFactory(
    DatabaseFactory factory, {
    String path = 'landeck_test.db',
  }) async {
    final Database db = await factory.openDatabase(
      path,
      version: schemaVersion,
    );
    await migrateDatabase(db);
    return AppDatabase._(db);
  }

  Future<String?> readSetting(String key) async {
    final Map<String, Object?>? record = await metaStore.record(key).get(db);
    return record?['value'] as String?;
  }

  Future<void> writeSetting(String key, String value) async {
    await metaStore.record(key).put(db, <String, Object?>{'value': value});
  }

  Future<void> close() => db.close();
}
