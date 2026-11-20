import 'package:sembast/sembast.dart';

import '../../core/utils/url_utils.dart';

/// Schema v1 stored a complete `url` on each service and separate `ipAddress` /
/// `hostname` fields on devices. Schema v2 stores a device-centric address plus
/// protocol/port/path on services. This migration preserves every old URL.
Future<void> migrateDatabase(Database db) async {
  final StoreRef<String, Map<String, Object?>> metaStore =
      StoreRef<String, Map<String, Object?>>('meta');
  final StoreRef<String, Map<String, Object?>> deviceStore =
      StoreRef<String, Map<String, Object?>>('devices');
  final StoreRef<String, Map<String, Object?>> serviceStore =
      StoreRef<String, Map<String, Object?>>('services');

  final Map<String, Object?>? meta =
      await metaStore.record('schema').get(db);
  final int currentVersion = (meta?['version'] as num?)?.toInt() ?? 0;
  if (currentVersion >= 2) {
    return;
  }

  await db.transaction((Transaction transaction) async {
    final List<RecordSnapshot<String, Map<String, Object?>>> deviceRecords =
        await deviceStore.find(transaction);
    final Map<String, Map<String, Object?>> devicesById =
        <String, Map<String, Object?>>{};
    final Map<String, String> addressToDeviceId = <String, String>{};

    for (final RecordSnapshot<String, Map<String, Object?>> record
        in deviceRecords) {
      final Map<String, Object?> old = record.value;
      final String address =
          (old['primaryAddress'] as String?)?.trim() ??
          (old['ipAddress'] as String?)?.trim() ??
          (old['hostname'] as String?)?.trim() ??
          '';
      final Map<String, Object?> updated = <String, Object?>{
        'id': old['id'] ?? record.key,
        'name': old['name'] ?? '',
        'deviceType': old['deviceType'] ?? 'other',
        'primaryAddress': address,
        'icon': old['icon'],
        'notes': old['notes'],
        'sortOrder': old['sortOrder'] ?? 0,
        'createdAt': old['createdAt'],
        'updatedAt': old['updatedAt'],
      };
      final String id = updated['id']! as String;
      devicesById[id] = updated;
      if (address.isNotEmpty) {
        addressToDeviceId[address.toLowerCase()] = id;
      }
      await deviceStore.record(record.key).put(transaction, updated);
    }

    final List<RecordSnapshot<String, Map<String, Object?>>> serviceRecords =
        await serviceStore.find(transaction);
    for (final RecordSnapshot<String, Map<String, Object?>> record
        in serviceRecords) {
      final Map<String, Object?> old = record.value;
      if (old.containsKey('protocol') && old.containsKey('customUrl')) {
        continue;
      }
      final String originalUrl = _legacyUrl(old);
      final Map<String, Object?> updated = Map<String, Object?>.of(old);
      updated.remove('url');
      updated.remove('host');

      final Uri? uri = Uri.tryParse(normalizeHttpUrl(originalUrl) ?? '');
      final String oldDeviceId = old['deviceId'] as String? ?? '';
      Map<String, Object?>? device = devicesById[oldDeviceId];
      final String host = uri?.host.toLowerCase() ?? '';
      if (device == null && host.isNotEmpty) {
        final String? matchedId = addressToDeviceId[host];
        if (matchedId != null) {
          device = devicesById[matchedId];
        }
      }

      bool linksToDevice = false;
      if (device != null && uri != null && uri.host.isNotEmpty) {
        final String deviceAddress =
            (device['primaryAddress'] as String? ?? '').toLowerCase();
        linksToDevice =
            deviceAddress == uri.host.toLowerCase() &&
            !uri.hasQuery &&
            !uri.hasFragment;
      }

      updated['protocol'] =
          uri?.scheme == 'https' ? 'https' : 'http';
      updated['port'] = uri != null && uri.hasPort ? uri.port : null;
      if (linksToDevice) {
        updated['deviceId'] = device!['id'];
        updated['path'] = uri!.path.isEmpty || uri.path == '/'
            ? null
            : uri.path;
        updated['customUrl'] = null;
      } else {
        // Keep the exact old URL, even if it cannot be parsed into parts.
        updated['deviceId'] = null;
        updated['path'] = null;
        updated['customUrl'] = originalUrl;
      }
      await serviceStore.record(record.key).put(transaction, updated);
    }

    await metaStore.record('schema').put(transaction, <String, Object?>{
      'version': 2,
    });
  });
}

String _legacyUrl(Map<String, Object?> map) {
  final String stored = (map['url'] as String?)?.trim() ?? '';
  if (stored.isNotEmpty) {
    return stored;
  }
  final String host = (map['host'] as String?)?.trim() ?? '';
  if (host.isEmpty) {
    return '';
  }
  final int? port = (map['port'] as num?)?.toInt();
  final String path = (map['path'] as String?) ?? '';
  return buildServiceUrl(
    address: host,
    protocol: 'http',
    port: port,
    path: path,
  );
}
