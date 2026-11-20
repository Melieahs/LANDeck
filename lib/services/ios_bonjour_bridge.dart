import 'dart:async';

import 'package:flutter/services.dart';

class IosBonjourResult {
  const IosBonjourResult({
    required this.ipAddress,
    required this.name,
    required this.serviceType,
    required this.port,
  });

  final String ipAddress;
  final String name;
  final String serviceType;
  final int port;

  factory IosBonjourResult.fromMap(Map<Object?, Object?> map) {
    return IosBonjourResult(
      ipAddress: map['ip'] as String? ?? '',
      name: map['name'] as String? ?? '',
      serviceType: map['type'] as String? ?? '',
      port: (map['port'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Native Bonjour browse on iOS.
///
/// Raw multicast sockets used by `multicast_dns` require a restricted Apple
/// multicast entitlement, while `NWBrowser` is the supported way to browse
/// Bonjour services inside an app. Results are resolved to an IP by opening a
/// short-lived TCP connection to the advertised service.
class IosBonjourBridge {
  const IosBonjourBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.example.landeck/bonjour',
  );

  static const List<String> serviceTypes = <String>[
    '_http._tcp',
    '_https._tcp',
    '_ssh._tcp',
    '_smb._tcp',
    '_device-info._tcp',
    '_workstation._tcp',
    '_airplay._tcp',
    '_googlecast._tcp',
  ];

  Future<List<IosBonjourResult>> browse({
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final List<IosBonjourResult> results = <IosBonjourResult>[];
    final Set<String> seen = <String>{};

    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'onResult') {
        return;
      }
      final Map<Object?, Object?>? args =
          call.arguments as Map<Object?, Object?>?;
      if (args == null) {
        return;
      }
      final IosBonjourResult item = IosBonjourResult.fromMap(args);
      if (item.ipAddress.isEmpty) {
        return;
      }
      final String key = '${item.ipAddress}|${item.name}|${item.port}';
      if (seen.add(key)) {
        results.add(item);
      }
    });

    try {
      await _channel.invokeMethod<void>('start', <String, Object?>{
        'types': serviceTypes,
      });
      await Future<void>.delayed(timeout);
    } finally {
      try {
        await _channel.invokeMethod<void>('stop');
      } on Object {
        // The scan will fail gracefully if the native side disappeared.
      }
      _channel.setMethodCallHandler(null);
    }
    return results;
  }
}
