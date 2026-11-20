import 'package:landeck/data/database/app_database.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:sembast/sembast_memory.dart';

Future<LanDeckRepository> createTestRepository() async {
  final AppDatabase database = await AppDatabase.openFromFactory(
    databaseFactoryMemory,
    path: 'landeck_test_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final LanDeckRepository repository = LanDeckRepository(database);
  await repository.load();
  return repository;
}
