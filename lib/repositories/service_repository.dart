import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/url_utils.dart';
import '../data/database/app_database.dart';
import '../models/device.dart';
import '../models/device_category.dart';
import '../models/download_task.dart';
import '../models/service.dart';

class ServiceConflictException implements Exception {
  const ServiceConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceConflictException implements Exception {
  const DeviceConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Single source of truth for the app.
///
/// All reads come from the on-device database loaded into memory; all writes go
/// to the database first and then notify the UI. There is intentionally no mock
/// implementation and no seeded data.
class LanDeckRepository extends ChangeNotifier {
  LanDeckRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  static const Uuid _uuid = Uuid();

  List<Service> _services = <Service>[];
  List<Device> _devices = <Device>[];
  List<DownloadTask> _downloads = <DownloadTask>[];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<Service> get services => List<Service>.unmodifiable(_services);
  List<Device> get devices => List<Device>.unmodifiable(_devices);
  List<DownloadTask> get downloads => List<DownloadTask>.unmodifiable(_downloads);

  int get activeDownloadCount =>
      _downloads.where((DownloadTask task) => task.isActive).length;

  List<Service> get favorites =>
      _services.where((Service service) => service.isFavorite).toList();

  int get onlineCount =>
      _services.where((Service service) => service.isOnline).length;

  Future<void> load() async {
    final List<RecordSnapshot<String, Map<String, Object?>>> deviceRecords =
        await AppDatabase.deviceStore.find(_appDatabase.db);
    _devices = deviceRecords
        .map(
          (RecordSnapshot<String, Map<String, Object?>> record) =>
              Device.fromMap(record.value),
        )
        .toList();
    _devices.sort(_compareDevices);

    final Map<String, Device> byId = <String, Device>{
      for (final Device device in _devices) device.id: device,
    };
    final List<RecordSnapshot<String, Map<String, Object?>>> serviceRecords =
        await AppDatabase.serviceStore.find(_appDatabase.db);
    _services = serviceRecords.map((
      RecordSnapshot<String, Map<String, Object?>> record,
    ) {
      final Service service = Service.fromMap(record.value);
      final Device? device = byId[service.deviceId];
      return service.copyWith(deviceAddress: () => device?.primaryAddress);
    }).toList();
    _services.sort(_compareServices);

    final List<RecordSnapshot<String, Map<String, Object?>>> downloadRecords =
        await AppDatabase.downloadStore.find(_appDatabase.db);
    _downloads = downloadRecords
        .map(
          (RecordSnapshot<String, Map<String, Object?>> record) =>
              DownloadTask.fromMap(record.value),
        )
        .toList();
    _downloads.sort(
      (DownloadTask a, DownloadTask b) => b.createdAt.compareTo(a.createdAt),
    );
    _loaded = true;
    notifyListeners();
  }

  int _compareServices(Service a, Service b) {
    final int order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0
        ? order
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _compareDevices(Device a, Device b) {
    final int order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0
        ? order
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Service? serviceById(String id) {
    for (final Service service in _services) {
      if (service.id == id) {
        return service;
      }
    }
    return null;
  }

  Device? deviceById(String? id) {
    if (id == null) {
      return null;
    }
    for (final Device device in _devices) {
      if (device.id == id) {
        return device;
      }
    }
    return null;
  }

  /// Finds the device whose primary address matches a scanned host.
  Device? findDeviceForHost(String host) {
    final String needle = host.trim().toLowerCase().replaceAll(
      RegExp(r'\.$'),
      '',
    );
    if (needle.isEmpty) {
      return null;
    }
    for (final Device device in _devices) {
      final String address = device.primaryAddress
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\.$'), '');
      if (address == needle) {
        return device;
      }
    }
    return null;
  }

  String deviceNameFor(Service service) {
    return deviceById(service.deviceId)?.name ?? '未分配设备';
  }

  List<Service> servicesForCategory(DeviceCategory category) {
    if (category == DeviceCategory.all) {
      return services;
    }
    return _services
        .where((Service service) => service.category == category)
        .toList();
  }

  Map<DeviceCategory, int> get categoryCounts {
    final Map<DeviceCategory, int> counts = <DeviceCategory, int>{
      DeviceCategory.all: _services.length,
    };
    for (final DeviceCategory category in DeviceCategory.values) {
      if (category == DeviceCategory.all) {
        continue;
      }
      counts[category] = _services
          .where((Service service) => service.category == category)
          .length;
    }
    return counts;
  }

  List<Service> servicesForDevice(Device device) {
    return _services
        .where((Service service) => service.deviceId == device.id)
        .toList();
  }

  int serviceCountForDevice(Device device) => servicesForDevice(device).length;

  List<Service> searchServices(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return services;
    }
    return _services.where((Service service) {
      final String deviceName = deviceNameFor(service);
      return <String>[
        service.name,
        service.url,
        service.address,
        service.categoryLabel,
        deviceName,
      ].join(' ').toLowerCase().contains(needle);
    }).toList();
  }

  /// Adds a service. Either [customUrl] is supplied, or [deviceId] resolves to a
  /// device so the URL can be composed from protocol/port/path.
  Future<Service> addService({
    required String name,
    String? deviceId,
    String protocol = 'http',
    int? port,
    String? path,
    String? customUrl,
    DeviceCategory? category,
    ServiceGlyph? icon,
    bool isFavorite = false,
    ServiceStatus? lastStatus,
    DateTime? lastCheckedAt,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ServiceConflictException('服务名称不能为空');
    }
    final Device? device = deviceById(deviceId);
    if (deviceId != null && device == null) {
      throw const ServiceConflictException('所属设备不存在或已被删除');
    }
    if (protocol != 'http' && protocol != 'https') {
      throw const ServiceConflictException('协议只能是 HTTP 或 HTTPS');
    }
    if (port != null && (port < 1 || port > 65535)) {
      throw const ServiceConflictException('端口必须在 1–65535 之间');
    }
    final String? normalizedCustom = _normalizeCustom(customUrl);
    if (normalizedCustom == null && device == null) {
      throw const ServiceConflictException('请选择设备并填写端口，或填写完整 URL');
    }

    final DateTime now = DateTime.now();
    final Service draft = Service(
      id: _uuid.v4(),
      name: trimmedName,
      deviceId: device?.id,
      deviceAddress: device?.primaryAddress,
      protocol: protocol,
      port: port,
      path: _normalizePath(path),
      customUrl: normalizedCustom,
      category: category,
      icon: icon,
      isFavorite: isFavorite,
      sortOrder: _nextServiceSortOrder(),
      lastStatus: lastStatus,
      lastCheckedAt: lastCheckedAt,
      healthCheckEnabled: false,
      createdAt: now,
      updatedAt: now,
    );
    _ensureUniqueUrl(draft.url);

    await AppDatabase.serviceStore
        .record(draft.id)
        .put(_appDatabase.db, draft.toMap());
    _services.add(draft);
    _services.sort(_compareServices);
    notifyListeners();
    return draft;
  }

  /// Convenience used by the device quick-add flow.
  Future<Service> addDeviceService({
    required String deviceId,
    required String name,
    required int? port,
    String protocol = 'http',
    String? path,
    DeviceCategory? category,
    ServiceGlyph? icon,
    bool isFavorite = false,
    ServiceStatus? lastStatus,
    DateTime? lastCheckedAt,
  }) {
    return addService(
      name: name,
      deviceId: deviceId,
      protocol: protocol,
      port: port,
      path: path,
      category: category,
      icon: icon,
      isFavorite: isFavorite,
      lastStatus: lastStatus,
      lastCheckedAt: lastCheckedAt,
    );
  }

  Future<Service> updateService(Service service) async {
    final Service? existing = serviceById(service.id);
    if (existing == null) {
      throw const ServiceConflictException('服务不存在或已被删除');
    }
    final String trimmedName = service.name.trim();
    if (trimmedName.isEmpty) {
      throw const ServiceConflictException('服务名称不能为空');
    }
    if (service.protocol != 'http' && service.protocol != 'https') {
      throw const ServiceConflictException('协议只能是 HTTP 或 HTTPS');
    }
    if (service.port != null && (service.port! < 1 || service.port! > 65535)) {
      throw const ServiceConflictException('端口必须在 1–65535 之间');
    }
    final Device? device = deviceById(service.deviceId);
    if (service.deviceId != null && device == null) {
      throw const ServiceConflictException('所属设备不存在或已被删除');
    }
    final String? normalizedCustom = _normalizeCustom(service.customUrl);
    if (normalizedCustom == null && device == null) {
      throw const ServiceConflictException('请选择设备并填写端口，或填写完整 URL');
    }

    final Service updated = service.copyWith(
      name: trimmedName,
      deviceAddress: () => device?.primaryAddress,
      protocol: service.protocol,
      port: () => service.port,
      path: () => _normalizePath(service.path),
      customUrl: () => normalizedCustom,
      updatedAt: DateTime.now(),
    );
    _ensureUniqueUrl(updated.url, exceptId: updated.id);

    await AppDatabase.serviceStore
        .record(updated.id)
        .put(_appDatabase.db, updated.toMap());
    final int index = _services.indexWhere(
      (Service item) => item.id == updated.id,
    );
    if (index >= 0) {
      _services[index] = updated;
      _services.sort(_compareServices);
    }
    notifyListeners();
    return updated;
  }

  String? _normalizeCustom(String? raw) {
    final String value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    final String? normalized = normalizeHttpUrl(value);
    if (normalized == null) {
      throw const ServiceConflictException('请输入有效的 HTTP 或 HTTPS 地址');
    }
    return normalized;
  }

  String? _normalizePath(String? raw) {
    final String value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  void _ensureUniqueUrl(String effectiveUrl, {String? exceptId}) {
    if (effectiveUrl.isEmpty) {
      throw const ServiceConflictException('服务地址为空，请检查设备地址与端口');
    }
    final String key = canonicalHttpUrl(effectiveUrl);
    for (final Service service in _services) {
      if (service.id == exceptId) {
        continue;
      }
      if (canonicalHttpUrl(service.url) == key) {
        throw const ServiceConflictException('该地址已经添加过了');
      }
    }
  }

  int _nextServiceSortOrder() {
    if (_services.isEmpty) {
      return 0;
    }
    return _services
            .map((Service service) => service.sortOrder)
            .reduce((int a, int b) => a > b ? a : b) +
        1;
  }

  Future<void> deleteService(String id) async {
    await AppDatabase.serviceStore.record(id).delete(_appDatabase.db);
    _services.removeWhere((Service service) => service.id == id);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final Service? service = serviceById(id);
    if (service == null) {
      return;
    }
    final Service updated = service.copyWith(
      isFavorite: !service.isFavorite,
      updatedAt: DateTime.now(),
    );
    await AppDatabase.serviceStore
        .record(id)
        .put(_appDatabase.db, updated.toMap());
    final int index = _services.indexWhere((Service item) => item.id == id);
    _services[index] = updated;
    notifyListeners();
  }

  /// Records a real reachability result from scanning or the WebView.
  Future<void> recordHealth(String id, ServiceStatus status) async {
    final Service? service = serviceById(id);
    if (service == null) {
      return;
    }
    final DateTime now = DateTime.now();
    final Service updated = service.copyWith(
      lastStatus: () => status,
      lastCheckedAt: () => now,
      updatedAt: now,
    );
    await AppDatabase.serviceStore
        .record(id)
        .put(_appDatabase.db, updated.toMap());
    final int index = _services.indexWhere((Service item) => item.id == id);
    _services[index] = updated;
    notifyListeners();
  }

  Future<Device> addDevice({
    required String name,
    required DeviceType deviceType,
    required String primaryAddress,
    String? icon,
    String? notes,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const DeviceConflictException('设备名称不能为空');
    }
    final String? address = normalizeDeviceAddress(primaryAddress);
    if (address == null) {
      throw const DeviceConflictException('请输入有效的设备 IP 或主机名');
    }
    _ensureUniqueAddress(address);

    final DateTime now = DateTime.now();
    final Device device = Device(
      id: _uuid.v4(),
      name: trimmedName,
      deviceType: deviceType,
      primaryAddress: address,
      icon: _emptyToNull(icon),
      notes: _emptyToNull(notes),
      sortOrder: _nextDeviceSortOrder(),
      createdAt: now,
      updatedAt: now,
    );
    await AppDatabase.deviceStore
        .record(device.id)
        .put(_appDatabase.db, device.toMap());
    _devices.add(device);
    _devices.sort(_compareDevices);
    notifyListeners();
    return device;
  }

  Future<Device> updateDevice(Device device) async {
    final String trimmedName = device.name.trim();
    if (trimmedName.isEmpty) {
      throw const DeviceConflictException('设备名称不能为空');
    }
    final String? address = normalizeDeviceAddress(device.primaryAddress);
    if (address == null) {
      throw const DeviceConflictException('请输入有效的设备 IP 或主机名');
    }
    _ensureUniqueAddress(address, exceptId: device.id);

    final Device updated = device.copyWith(
      name: trimmedName,
      primaryAddress: address,
      icon: () => _emptyToNull(device.icon),
      notes: () => _emptyToNull(device.notes),
      updatedAt: DateTime.now(),
    );
    await AppDatabase.deviceStore
        .record(updated.id)
        .put(_appDatabase.db, updated.toMap());
    // Reload so every linked service receives the new device address.
    await load();
    return updated;
  }

  void _ensureUniqueAddress(String address, {String? exceptId}) {
    final String needle = address.toLowerCase();
    for (final Device device in _devices) {
      if (device.id == exceptId) {
        continue;
      }
      if (device.primaryAddress.trim().toLowerCase() == needle) {
        throw const DeviceConflictException('该设备地址已经存在');
      }
    }
  }

  /// Deletes a device but keeps its services. Each service is frozen to its
  /// current effective URL, then moved to 未分配设备, so it stays accessible.
  Future<void> deleteDevice(String id) async {
    final Device? device = deviceById(id);
    await _appDatabase.db.transaction((Transaction transaction) async {
      final List<RecordSnapshot<String, Map<String, Object?>>> linked =
          await AppDatabase.serviceStore.find(
            transaction,
            finder: Finder(filter: Filter.equals('deviceId', id)),
          );
      final DateTime now = DateTime.now();
      for (final RecordSnapshot<String, Map<String, Object?>> record
          in linked) {
        final Service service = Service.fromMap(record.value)
            .copyWith(deviceAddress: () => device?.primaryAddress);
        final String frozenUrl = service.url;
        await AppDatabase.serviceStore.record(record.key).update(
          transaction,
          <String, Object?>{
            'deviceId': null,
            'customUrl': frozenUrl.isEmpty ? null : frozenUrl,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
      await AppDatabase.deviceStore.record(id).delete(transaction);
    });
    await load();
  }


  DownloadTask? downloadById(String id) {
    for (final DownloadTask task in _downloads) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<DownloadTask> addDownload(DownloadTask task) async {
    await AppDatabase.downloadStore
        .record(task.id)
        .put(_appDatabase.db, task.toMap());
    _downloads.insert(0, task);
    notifyListeners();
    return task;
  }

  Future<void> updateDownload(DownloadTask task) async {
    final int index = _downloads.indexWhere(
      (DownloadTask item) => item.id == task.id,
    );
    if (index < 0) {
      return;
    }
    await AppDatabase.downloadStore
        .record(task.id)
        .put(_appDatabase.db, task.toMap());
    _downloads[index] = task;
    notifyListeners();
  }

  Future<void> deleteDownload(String id) async {
    await AppDatabase.downloadStore.record(id).delete(_appDatabase.db);
    _downloads.removeWhere((DownloadTask task) => task.id == id);
    notifyListeners();
  }

  Future<void> clearCompletedDownloads() async {
    final List<DownloadTask> completed = _downloads
        .where((DownloadTask task) => !task.isActive)
        .toList();
    for (final DownloadTask task in completed) {
      await AppDatabase.downloadStore.record(task.id).delete(_appDatabase.db);
    }
    _downloads.removeWhere((DownloadTask task) => !task.isActive);
    notifyListeners();
  }

  int _nextDeviceSortOrder() {
    if (_devices.isEmpty) {
      return 0;
    }
    return _devices
            .map((Device device) => device.sortOrder)
            .reduce((int a, int b) => a > b ? a : b) +
        1;
  }

  String? _emptyToNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

extension LanDeckBackupRepository on LanDeckRepository {
  /// Exports only the user's configuration. Download history and HTTP
  /// credentials are intentionally excluded from the portable snapshot.
  Map<String, Object?> exportBackup() {
    return <String, Object?>{
      'format': 'landeck-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'devices': devices.map((Device device) => device.toMap()).toList(),
      'services': services.map((Service service) => service.toMap()).toList(),
    };
  }

  Future<BackupImportResult> importBackup(Map<String, Object?> data) async {
    if (data['format'] != 'landeck-backup' || data['version'] != 1) {
      throw const FormatException('不是有效的 LANDeck 备份文件');
    }
    final List<Object?> rawDevices = data['devices'] as List<Object?>? ?? <Object?>[];
    final List<Object?> rawServices =
        data['services'] as List<Object?>? ?? <Object?>[];
    final List<Device> importedDevices = <Device>[];
    final Set<String> deviceIds = <String>{};
    for (final Object? item in rawDevices) {
      if (item is! Map) {
        throw const FormatException('备份中的设备数据格式不正确');
      }
      final Device device = Device.fromMap(Map<String, Object?>.from(item));
      if (device.id.isEmpty || device.name.trim().isEmpty) {
        throw const FormatException('备份中存在缺少 ID 或名称的设备');
      }
      if (!deviceIds.add(device.id)) {
        throw const FormatException('备份中存在重复的设备 ID');
      }
      importedDevices.add(device);
    }

    final List<Service> importedServices = <Service>[];
    final Set<String> serviceIds = <String>{};
    for (final Object? item in rawServices) {
      if (item is! Map) {
        throw const FormatException('备份中的服务数据格式不正确');
      }
      Service service = Service.fromMap(Map<String, Object?>.from(item));
      if (service.id.isEmpty || service.name.trim().isEmpty) {
        throw const FormatException('备份中存在缺少 ID 或名称的服务');
      }
      if (!serviceIds.add(service.id)) {
        throw const FormatException('备份中存在重复的服务 ID');
      }
      if (service.deviceId != null && !deviceIds.contains(service.deviceId)) {
        service = service.copyWith(deviceId: () => null);
      }
      importedServices.add(service);
    }

    await _appDatabase.db.transaction((Transaction transaction) async {
      await AppDatabase.deviceStore.delete(transaction);
      await AppDatabase.serviceStore.delete(transaction);
      for (final Device device in importedDevices) {
        await AppDatabase.deviceStore
            .record(device.id)
            .put(transaction, device.toMap());
      }
      for (final Service service in importedServices) {
        await AppDatabase.serviceStore
            .record(service.id)
            .put(transaction, service.toMap());
      }
    });
    await load();
    return BackupImportResult(
      devices: importedDevices.length,
      services: importedServices.length,
    );
  }
}

class BackupImportResult {
  const BackupImportResult({required this.devices, required this.services});

  final int devices;
  final int services;
}
