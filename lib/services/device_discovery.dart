import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../core/utils/html_utils.dart';
import '../core/utils/network_utils.dart';
import '../models/device.dart';
import '../models/discovered_device.dart';
import '../models/scan_candidate.dart';
import 'multicast_lock.dart';

class _DeviceBuilder {
  _DeviceBuilder(this.ipAddress);

  final String ipAddress;
  final Set<DiscoverySource> sources = <DiscoverySource>{};
  final Set<String> serviceTypes = <String>{};
  String? name;
  String? hostname;
  String? manufacturer;
  String? model;
  DeviceType? typeHint;
  bool activeHost = false;
}

/// Phase 1 discovery: find devices, not services.
///
/// mDNS and SSDP are used first. A bounded TCP liveness probe (three ports)
/// supplements hosts that do not advertise themselves. It never scans web
/// service ports and never creates services.
class DeviceDiscoveryService {
  DeviceDiscoveryService();

  static const List<String> mdnsServiceTypes = <String>[
    '_http._tcp.local',
    '_https._tcp.local',
    '_ssh._tcp.local',
    '_smb._tcp.local',
    '_workstation._tcp.local',
    '_device-info._tcp.local',
    '_airplay._tcp.local',
    '_googlecast._tcp.local',
    '_home-assistant._tcp.local',
    '_printer._tcp.local',
  ];

  static const List<int> _livenessPorts = <int>[80, 443, 22, 445, 548];
  static const Duration _livenessTimeout = Duration(milliseconds: 280);
  static const int _livenessConcurrency = 64;

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<DeviceDiscoveryResult> scan(
    LanNetworkInfo network, {
    required ValueChanged<DeviceDiscoveryProgress> onProgress,
  }) async {
    _cancelled = false;
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> errors = <String>[];
    final List<String> hosts = hostsForCidr(
      network.ipAddress,
      network.prefixLength,
    );
    final Map<String, _DeviceBuilder> builders = <String, _DeviceBuilder>{};

    if (hosts.isEmpty) {
      return DeviceDiscoveryResult(
        network: network,
        devices: const <DiscoveredDevice>[],
        errors: const <String>['无法计算当前 Wi-Fi 子网'],
        cancelled: false,
        duration: stopwatch.elapsed,
        mdnsCount: 0,
        ssdpCount: 0,
        hostCount: 0,
      );
    }

    final Set<String> subnet = hosts.toSet();
    onProgress(
      const DeviceDiscoveryProgress(
        phase: 'mdns',
        message: '正在通过 mDNS 查找主动广播的设备…',
      ),
    );

    final MulticastLock lock = MulticastLock();
    await lock.acquire();
    int mdnsCount = 0;
    try {
      final List<_MdnsDevice> found = await _discoverMdns(subnet, onProgress)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => const <_MdnsDevice>[],
          );
      mdnsCount = found.length;
      for (final _MdnsDevice item in found) {
        final _DeviceBuilder builder = builders.putIfAbsent(
          item.ipAddress,
          () => _DeviceBuilder(item.ipAddress),
        );
        builder
          ..sources.add(DiscoverySource.mdns)
          ..name ??= item.instanceName
          ..hostname ??= item.hostname
          ..typeHint ??= item.typeHint;
        builder.serviceTypes.add(item.serviceType);
      }
      if (found.isEmpty) {
        errors.add('mDNS 未收到广播（部分设备可能未启用 mDNS）');
      }
    } on Object catch (error) {
      errors.add('mDNS 查询失败：$error');
    } finally {
      await lock.release();
    }

    if (_cancelled) {
      return _result(
        network,
        builders,
        errors,
        stopwatch,
        mdnsCount: mdnsCount,
      );
    }

    onProgress(
      const DeviceDiscoveryProgress(
        phase: 'ssdp',
        message: '正在通过 SSDP / UPnP 查找设备…',
      ),
    );
    int ssdpCount = 0;
    try {
      final List<_SsdpDevice> found = await _discoverSsdp(subnet).timeout(
        const Duration(seconds: 6),
        onTimeout: () => const <_SsdpDevice>[],
      );
      ssdpCount = found.length;
      for (final _SsdpDevice item in found) {
        final _DeviceBuilder builder = builders.putIfAbsent(
          item.ipAddress,
          () => _DeviceBuilder(item.ipAddress),
        );
        builder
          ..sources.add(DiscoverySource.ssdp)
          ..name ??= item.name
          ..manufacturer ??= item.manufacturer
          ..model ??= item.model
          ..typeHint ??= item.typeHint;
      }
      if (found.isEmpty) {
        errors.add('SSDP 未收到响应（不影响主机发现）');
      }
    } on Object catch (error) {
      errors.add('SSDP 查询失败：$error');
    }

    if (_cancelled) {
      return _result(
        network,
        builders,
        errors,
        stopwatch,
        mdnsCount: mdnsCount,
        ssdpCount: ssdpCount,
      );
    }

    onProgress(
      DeviceDiscoveryProgress(
        phase: 'host',
        message: '正在确认当前子网内的活跃主机…',
        total: hosts.length,
      ),
    );
    int hostCount = 0;
    try {
      final Set<String> active = await _probeActiveHosts(
        hosts,
        builders.keys.toSet(),
        onProgress,
      );
      hostCount = active.length;
      for (final String ip in active) {
        final _DeviceBuilder builder = builders.putIfAbsent(
          ip,
          () => _DeviceBuilder(ip),
        );
        builder
          ..sources.add(DiscoverySource.host)
          ..activeHost = true;
      }
    } on Object catch (error) {
      errors.add('主机发现失败：$error');
    }

    return _result(
      network,
      builders,
      errors,
      stopwatch,
      mdnsCount: mdnsCount,
      ssdpCount: ssdpCount,
      hostCount: hostCount,
    );
  }

  DeviceDiscoveryResult _result(
    LanNetworkInfo network,
    Map<String, _DeviceBuilder> builders,
    List<String> errors,
    Stopwatch stopwatch, {
    required int mdnsCount,
    int ssdpCount = 0,
    int hostCount = 0,
  }) {
    stopwatch.stop();
    final List<DiscoveredDevice> devices =
        builders.values
            .map(
              (_DeviceBuilder builder) => DiscoveredDevice(
                ipAddress: builder.ipAddress,
                sources: builder.sources,
                name: builder.name,
                hostname: builder.hostname,
                manufacturer: builder.manufacturer,
                model: builder.model,
                deviceTypeHint: builder.typeHint,
                serviceTypes: builder.serviceTypes,
                isActiveHost:
                    builder.activeHost &&
                    builder.sources.length == 1 &&
                    builder.sources.contains(DiscoverySource.host),
              ),
            )
            .toList()
          ..sort((DiscoveredDevice a, DiscoveredDevice b) {
            final int bySource = b.sources.length.compareTo(a.sources.length);
            if (bySource != 0) {
              return bySource;
            }
            return _ipCompare(a.ipAddress, b.ipAddress);
          });
    return DeviceDiscoveryResult(
      network: network,
      devices: devices,
      errors: errors,
      cancelled: _cancelled,
      duration: stopwatch.elapsed,
      mdnsCount: mdnsCount,
      ssdpCount: ssdpCount,
      hostCount: hostCount,
    );
  }

  int _ipCompare(String a, String b) {
    final List<int> left = a.split('.').map(int.parse).toList();
    final List<int> right = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 4; i++) {
      if (left[i] != right[i]) {
        return left[i].compareTo(right[i]);
      }
    }
    return 0;
  }

  Future<List<_MdnsDevice>> _discoverMdns(
    Set<String> subnet,
    ValueChanged<DeviceDiscoveryProgress> onProgress,
  ) async {
    final MDnsClient client = MDnsClient();
    final List<_MdnsDevice> found = <_MdnsDevice>[];
    try {
      await client.start(
        onError: (Object error) {
          // Some interfaces reject multicast; other interfaces still work.
        },
      );
      for (final String type in mdnsServiceTypes) {
        if (_cancelled) {
          break;
        }
        onProgress(
          DeviceDiscoveryProgress(phase: 'mdns', message: 'mDNS 查询 $type'),
        );
        try {
          final PtrResourceRecord ptr = await client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(type),
              )
              .first
              .timeout(const Duration(seconds: 2));
          final SrvResourceRecord srv = await client
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )
              .first
              .timeout(const Duration(seconds: 2));
          final IPAddressResourceRecord address = await client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .first
              .timeout(const Duration(seconds: 2));
          final String ip = address.address.address;
          if (!subnet.contains(ip)) {
            continue;
          }
          found.add(
            _MdnsDevice(
              ipAddress: ip,
              hostname: _cleanMdnsName(srv.target),
              instanceName: _instanceName(ptr.domainName, type),
              serviceType: type,
              typeHint: _typeForMdns(type),
            ),
          );
        } on Object {
          // Not every type exists on every network.
        }
      }
    } finally {
      client.stop();
    }
    return found;
  }

  String _cleanMdnsName(String value) {
    String result = value;
    if (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
    return result.replaceAll(r'\032', ' ');
  }

  String? _instanceName(String domainName, String type) {
    final String suffix = '.$type';
    String value = domainName;
    if (value.endsWith(suffix)) {
      value = value.substring(0, value.length - suffix.length);
    } else if (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    value = _cleanMdnsName(value);
    return value.isEmpty ? null : value;
  }

  DeviceType? _typeForMdns(String type) {
    if (type.startsWith('_http') || type.startsWith('_https')) {
      return null;
    }
    if (type.startsWith('_airplay') ||
        type.startsWith('_googlecast') ||
        type.startsWith('_raop')) {
      return DeviceType.media;
    }
    if (type.startsWith('_smb') || type.startsWith('_workstation')) {
      return DeviceType.computer;
    }
    return null;
  }

  Future<List<_SsdpDevice>> _discoverSsdp(Set<String> subnet) async {
    RawDatagramSocket? socket;
    final Map<String, String> locations = <String, String>{};
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      late StreamSubscription<RawSocketEvent> subscription;
      subscription = socket.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final Datagram? datagram = socket?.receive();
        if (datagram == null) {
          return;
        }
        final String ip = datagram.address.address;
        if (!subnet.contains(ip)) {
          return;
        }
        final String text = utf8.decode(datagram.data, allowMalformed: true);
        locations[ip] ??= _header(text, 'location') ?? '';
      });
      const String message =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n'
          '\r\n';
      socket.send(
        utf8.encode(message),
        InternetAddress('239.255.255.250'),
        1900,
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      await subscription.cancel();
    } on Object {
      return const <_SsdpDevice>[];
    } finally {
      socket?.close();
    }

    final List<_SsdpDevice> devices = <_SsdpDevice>[];
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..idleTimeout = const Duration(seconds: 1)
      ..badCertificateCallback = (
        X509Certificate cert,
        String host,
        int port,
      ) => true;
    try {
      for (final MapEntry<String, String> entry in locations.entries) {
        if (_cancelled) {
          break;
        }
        String? name;
        String? manufacturer;
        String? model;
        DeviceType? typeHint;
        if (entry.value.isNotEmpty) {
          try {
            final Uri uri = Uri.parse(entry.value);
            final HttpClientRequest request = await client
                .getUrl(uri)
                .timeout(const Duration(seconds: 2));
            final HttpClientResponse response = await request.close().timeout(
              const Duration(seconds: 2),
            );
            final List<int> bytes = <int>[];
            await for (final List<int> chunk in response.timeout(
              const Duration(seconds: 2),
            )) {
              bytes.addAll(chunk);
              if (bytes.length >= 32768) {
                break;
              }
            }
            final String xml = utf8.decode(bytes, allowMalformed: true);
            name = _xml(xml, 'friendlyName');
            manufacturer = _xml(xml, 'manufacturer');
            model = _xml(xml, 'modelName') ?? _xml(xml, 'modelDescription');
            typeHint = _typeForUpnp(xml);
          } on Object {
            // A device may answer SSDP but refuse the description request.
          }
        }
        devices.add(
          _SsdpDevice(
            ipAddress: entry.key,
            name: name,
            manufacturer: manufacturer,
            model: model,
            typeHint: typeHint,
          ),
        );
      }
    } finally {
      client.close(force: true);
    }
    return devices;
  }

  String? _header(String text, String name) {
    for (final String line in text.split(RegExp(r'\r?\n'))) {
      final int index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      if (line.substring(0, index).trim().toLowerCase() == name) {
        return line.substring(index + 1).trim();
      }
    }
    return null;
  }

  String? _xml(String xml, String tag) {
    final RegExpMatch? match = RegExp(
      '<$tag[^>]*>(.*?)</$tag>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(xml);
    if (match == null) {
      return null;
    }
    final String value = decodeBasicHtmlEntities(
      match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
    );
    return value.isEmpty ? null : value;
  }

  DeviceType? _typeForUpnp(String xml) {
    final String lower = xml.toLowerCase();
    if (lower.contains('mediaserver') ||
        lower.contains('media renderer') ||
        lower.contains('tv')) {
      return DeviceType.media;
    }
    if (lower.contains('internetgatewaydevice') || lower.contains('router')) {
      return DeviceType.router;
    }
    if (lower.contains('nas') || lower.contains('storage')) {
      return DeviceType.nas;
    }
    return null;
  }

  Future<Set<String>> _probeActiveHosts(
    List<String> hosts,
    Set<String> alreadyKnown,
    ValueChanged<DeviceDiscoveryProgress> onProgress,
  ) async {
    final List<String> targets = hosts
        .where((String host) => !alreadyKnown.contains(host))
        .toList();
    final Set<String> active = <String>{};
    int nextIndex = 0;
    int completed = 0;

    Future<void> worker() async {
      while (!_cancelled) {
        final int index = nextIndex++;
        if (index >= targets.length) {
          return;
        }
        final String host = targets[index];
        for (final int port in _livenessPorts) {
          try {
            final Socket socket = await Socket.connect(
              host,
              port,
              timeout: _livenessTimeout,
            );
            socket.destroy();
            active.add(host);
            break;
          } on Object {
            // No listener on this liveness probe; try the next one.
          }
        }
        completed++;
        if (completed % 16 == 0 || completed == targets.length) {
          onProgress(
            DeviceDiscoveryProgress(
              phase: 'host',
              message: '已确认 $completed / ${targets.length} 台主机',
              completed: completed,
              total: targets.length,
            ),
          );
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(_livenessConcurrency, (_) => worker()),
    );
    return active;
  }
}

class _MdnsDevice {
  const _MdnsDevice({
    required this.ipAddress,
    required this.hostname,
    required this.instanceName,
    required this.serviceType,
    this.typeHint,
  });

  final String ipAddress;
  final String hostname;
  final String? instanceName;
  final String serviceType;
  final DeviceType? typeHint;
}

class _SsdpDevice {
  const _SsdpDevice({
    required this.ipAddress,
    this.name,
    this.manufacturer,
    this.model,
    this.typeHint,
  });

  final String ipAddress;
  final String? name;
  final String? manufacturer;
  final String? model;
  final DeviceType? typeHint;
}
