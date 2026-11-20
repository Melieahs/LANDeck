import 'device.dart';
import 'scan_candidate.dart';

/// Where a device came from during phase 1 discovery.
enum DiscoverySource { mdns, ssdp, host }

extension DiscoverySourceLabels on DiscoverySource {
  String get label => switch (this) {
    DiscoverySource.mdns => 'mDNS',
    DiscoverySource.ssdp => 'SSDP',
    DiscoverySource.host => '主机发现',
  };
}

/// A temporary device discovered on the LAN. It never enters the database
/// until the user reviews it and taps 添加设备.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.ipAddress,
    required this.sources,
    this.name,
    this.hostname,
    this.manufacturer,
    this.model,
    this.deviceTypeHint,
    this.serviceTypes = const <String>{},
    this.isActiveHost = false,
  });

  final String ipAddress;
  final Set<DiscoverySource> sources;
  final String? name;
  final String? hostname;
  final String? manufacturer;
  final String? model;

  /// A suggestion only; the user can change it before saving.
  final DeviceType? deviceTypeHint;
  final Set<String> serviceTypes;

  /// True when only an active host was confirmed, with no advertised service.
  final bool isActiveHost;

  String get displayName {
    final String? value = name?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    final String? host = hostname?.trim();
    if (host != null && host.isNotEmpty) {
      return host;
    }
    return ipAddress;
  }

  String get sourceLabel =>
      sources.map((DiscoverySource source) => source.label).join(' · ');

  String get typeLabel =>
      deviceTypeHint?.label ?? (isActiveHost ? '未知设备' : '待识别');

  String get detailLabel {
    final List<String> parts = <String>[];
    if (manufacturer != null && manufacturer!.isNotEmpty) {
      parts.add(manufacturer!);
    }
    if (model != null && model!.isNotEmpty) {
      parts.add(model!);
    }
    final List<String> services = serviceTypes.toList()..sort();
    if (services.isNotEmpty) {
      parts.add(services.map(_shortServiceType).join(' · '));
    }
    return parts.join(' · ');
  }

  DiscoveredDevice copyWith({
    String? name,
    String? hostname,
    DeviceType? deviceTypeHint,
    bool? isActiveHost,
  }) {
    return DiscoveredDevice(
      ipAddress: ipAddress,
      sources: sources,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      manufacturer: manufacturer,
      model: model,
      deviceTypeHint: deviceTypeHint ?? this.deviceTypeHint,
      serviceTypes: serviceTypes,
      isActiveHost: isActiveHost ?? this.isActiveHost,
    );
  }

  static String _shortServiceType(String type) {
    String value = type;
    if (value.endsWith('.local')) {
      value = value.substring(0, value.length - 6);
    }
    if (value.startsWith('_')) {
      value = value.substring(1);
    }
    final int dot = value.indexOf('._');
    if (dot > 0) {
      value = value.substring(0, dot);
    }
    return value;
  }
}

class DeviceDiscoveryProgress {
  const DeviceDiscoveryProgress({
    required this.phase,
    required this.message,
    this.completed = 0,
    this.total = 0,
  });

  final String phase;
  final String message;
  final int completed;
  final int total;

  double get ratio => total <= 0 ? 0 : (completed / total).clamp(0, 1);
}

class DeviceDiscoveryResult {
  const DeviceDiscoveryResult({
    required this.network,
    required this.devices,
    required this.errors,
    required this.cancelled,
    required this.duration,
    required this.mdnsCount,
    required this.ssdpCount,
    required this.hostCount,
  });

  final LanNetworkInfo network;
  final List<DiscoveredDevice> devices;
  final List<String> errors;
  final bool cancelled;
  final Duration duration;
  final int mdnsCount;
  final int ssdpCount;
  final int hostCount;
}
