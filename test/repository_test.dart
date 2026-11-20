import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/data/database/app_database.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/models/device_category.dart';
import 'package:landeck/models/service.dart';
import 'package:landeck/core/utils/url_utils.dart';
import 'package:landeck/repositories/service_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';

import 'test_helpers.dart';

void main() {
  test('url normalization and duplicate keys', () {
    expect(
      normalizeForTest('192.168.1.10:8080/docker'),
      'http://192.168.1.10:8080/docker',
    );
    expect(
      normalizeForTest('https://nas.local'),
      'https://nas.local',
    );
    expect(normalizeForTest('ftp://nas.local'), isNull);
  });

  test('service and device counters come from persisted data', () async {
    final LanDeckRepository repository = await createTestRepository();
    final Device device = await repository.addDevice(
      name: '书房 NAS',
      deviceType: DeviceType.nas,
      primaryAddress: '192.168.1.10',
    );
    final Service service = await repository.addService(
      name: '飞牛',
      deviceId: device.id,
      port: 5666,
      category: DeviceCategory.nas,
      isFavorite: true,
    );

    expect(repository.services.length, 1);
    expect(repository.favorites.single.id, service.id);
    expect(repository.categoryCounts[DeviceCategory.nas], 1);
    expect(repository.onlineCount, 0);
    expect(repository.deviceNameFor(service), '书房 NAS');

    await repository.recordHealth(service.id, ServiceStatus.online);
    expect(repository.onlineCount, 1);
    expect(repository.serviceById(service.id)!.statusLabel, '在线');
  });

  test('deleting a device unassigns its services, never deletes them', () async {
    final LanDeckRepository repository = await createTestRepository();
    final Device device = await repository.addDevice(
      name: '客厅路由',
      deviceType: DeviceType.router,
      primaryAddress: '192.168.1.1',
    );
    final Service service = await repository.addService(
      name: 'OpenWrt',
      deviceId: device.id,
    );

    await repository.deleteDevice(device.id);

    expect(repository.devices, isEmpty);
    expect(repository.services.single.id, service.id);
    expect(repository.services.single.deviceId, isNull);
    expect(repository.deviceNameFor(repository.services.single), '未分配设备');
  });



  test('deleting a device freezes linked service URLs', () async {
    final LanDeckRepository repository = await createTestRepository();
    final Device device = await repository.addDevice(
      name: 'NAS',
      deviceType: DeviceType.nas,
      primaryAddress: '192.168.1.10',
    );
    final Service service = await repository.addService(
      name: 'Jellyfin',
      deviceId: device.id,
      port: 8096,
      path: '/web',
    );
    final String before = service.url;

    await repository.deleteDevice(device.id);

    final Service survivor = repository.serviceById(service.id)!;
    expect(survivor.deviceId, isNull);
    expect(survivor.customUrl, before);
    expect(survivor.url, before);
    expect(repository.devices, isEmpty);
    expect(repository.services.length, 1);
  });

  test('device service URL follows device address changes', () async {
    final LanDeckRepository repository = await createTestRepository();
    final Device device = await repository.addDevice(
      name: '飞牛 NAS',
      deviceType: DeviceType.nas,
      primaryAddress: '192.168.1.10',
    );
    final Service service = await repository.addService(
      name: 'Jellyfin',
      deviceId: device.id,
      port: 8096,
      path: '/web',
      category: DeviceCategory.media,
    );
    expect(service.url, 'http://192.168.1.10:8096/web');

    await repository.updateDevice(
      device.copyWith(primaryAddress: '192.168.1.20'),
    );
    expect(
      repository.serviceById(service.id)!.url,
      'http://192.168.1.20:8096/web',
    );
  });

  test('custom URL service stays independent from device address changes', () async {
    final LanDeckRepository repository = await createTestRepository();
    final Device device = await repository.addDevice(
      name: 'NAS',
      deviceType: DeviceType.nas,
      primaryAddress: '192.168.1.10',
    );
    final Service service = await repository.addService(
      name: '反向代理 Jellyfin',
      deviceId: device.id,
      customUrl: 'https://jellyfin.example.com',
    );
    await repository.updateDevice(
      device.copyWith(primaryAddress: '192.168.1.99'),
    );
    expect(
      repository.serviceById(service.id)!.url,
      'https://jellyfin.example.com',
    );
  });

  test('migrates v1 full-URL services to device-centric data', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'landeck_migration',
    );
    final String path = p.join(directory.path, 'legacy.db');
    final Database legacy = await databaseFactoryIo.openDatabase(
      path,
      version: 1,
    );
    final StoreRef<String, Map<String, Object?>> devices =
        StoreRef<String, Map<String, Object?>>('devices');
    final StoreRef<String, Map<String, Object?>> services =
        StoreRef<String, Map<String, Object?>>('services');
    final StoreRef<String, Map<String, Object?>> meta =
        StoreRef<String, Map<String, Object?>>('meta');
    await devices.record('d1').put(legacy, <String, Object?>{
      'id': 'd1',
      'name': '飞牛 NAS',
      'deviceType': 'nas',
      'ipAddress': '192.168.1.10',
      'sortOrder': 0,
      'createdAt': DateTime(2024).toIso8601String(),
      'updatedAt': DateTime(2024).toIso8601String(),
    });
    await services.record('s1').put(legacy, <String, Object?>{
      'id': 's1',
      'name': 'Jellyfin',
      'deviceId': 'd1',
      'url': 'http://192.168.1.10:8096/web',
      'category': 'media',
      'isFavorite': true,
      'sortOrder': 0,
      'createdAt': DateTime(2024).toIso8601String(),
      'updatedAt': DateTime(2024).toIso8601String(),
    });
    await services.record('s2').put(legacy, <String, Object?>{
      'id': 's2',
      'name': 'CasaOS',
      'deviceId': null,
      'url': 'http://10.0.0.2:8080/?token=abc',
      'isFavorite': false,
      'sortOrder': 1,
      'createdAt': DateTime(2024).toIso8601String(),
      'updatedAt': DateTime(2024).toIso8601String(),
    });
    await meta.record('schema').put(legacy, <String, Object?>{'version': 1});
    await legacy.close();

    final AppDatabase upgraded = await AppDatabase.openFromFactory(
      databaseFactoryIo,
      path: path,
    );
    final LanDeckRepository repository = LanDeckRepository(upgraded);
    await repository.load();

    final Service linked = repository.serviceById('s1')!;
    expect(linked.deviceId, 'd1');
    expect(linked.customUrl, isNull);
    expect(linked.port, 8096);
    expect(linked.path, '/web');
    expect(linked.url, 'http://192.168.1.10:8096/web');

    final Service custom = repository.serviceById('s2')!;
    expect(custom.deviceId, isNull);
    expect(custom.customUrl, 'http://10.0.0.2:8080/?token=abc');
    expect(custom.url, 'http://10.0.0.2:8080/?token=abc');
    await upgraded.close();
    await directory.delete(recursive: true);
  });

  test('service survives closing and reopening the database', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'landeck_persistence',
    );
    final String path = p.join(directory.path, 'landeck.db');
    final AppDatabase first = await AppDatabase.openFromFactory(
      databaseFactoryIo,
      path: path,
    );
    final LanDeckRepository repository = LanDeckRepository(first);
    await repository.load();
    await repository.addService(name: 'Jellyfin', customUrl: 'http://10.0.0.2:8096');
    await first.close();

    final AppDatabase second = await AppDatabase.openFromFactory(
      databaseFactoryIo,
      path: path,
    );
    final LanDeckRepository reopened = LanDeckRepository(second);
    await reopened.load();

    expect(reopened.services.single.name, 'Jellyfin');
    expect(reopened.services.single.url, 'http://10.0.0.2:8096');
    await second.close();
    await directory.delete(recursive: true);
  });
}

String? normalizeForTest(String input) => normalizeHttpUrl(input);
