import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/device.dart';
import 'package:landeck/repositories/service_repository.dart';

import 'test_helpers.dart';

void main() {
  test('backup exports and restores devices and services', () async {
    final LanDeckRepository source = await createTestRepository();
    final Device device = await source.addDevice(
      name: 'Living Room NAS',
      deviceType: DeviceType.nas,
      primaryAddress: '192.168.1.10',
    );
    await source.addDeviceService(
      deviceId: device.id,
      name: 'Jellyfin',
      port: 8096,
      path: '/web',
    );
    await source.addService(
      name: 'CasaOS',
      customUrl: 'http://192.168.1.10:80',
    );

    final Map<String, Object?> snapshot = source.exportBackup();
    expect(snapshot['format'], 'landeck-backup');
    expect(snapshot['version'], 1);

    final LanDeckRepository target = await createTestRepository();
    final BackupImportResult result = await target.importBackup(snapshot);
    expect(result.devices, 1);
    expect(result.services, 2);
    expect(target.devices.single.name, 'Living Room NAS');
    expect(target.services.length, 2);

    final service = target.services.firstWhere(
      (item) => item.name == 'Jellyfin',
    );
    expect(service.deviceId, device.id);
    expect(service.url, 'http://192.168.1.10:8096/web');
  });

  test('backup rejects invalid format', () async {
    final LanDeckRepository repository = await createTestRepository();
    expect(
      () => repository.importBackup(<String, Object?>{'format': 'other'}),
      throwsFormatException,
    );
  });
}
