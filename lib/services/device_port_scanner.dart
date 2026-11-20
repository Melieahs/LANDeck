import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/utils/html_utils.dart';
import '../core/utils/url_utils.dart';

enum PortScanCategory { confirmedHttps, confirmedHttp, candidate, openPort }

extension PortScanCategoryLabels on PortScanCategory {
  String get label => switch (this) {
    PortScanCategory.confirmedHttps => '已确认 HTTPS',
    PortScanCategory.confirmedHttp => '已确认 HTTP',
    PortScanCategory.candidate => '候选服务',
    PortScanCategory.openPort => '端口开放',
  };
}

class DevicePortResult {
  const DevicePortResult({
    required this.port,
    required this.tcpOpen,
    required this.category,
    this.url,
    this.scheme,
    this.title,
    this.statusCode,
    this.server,
    this.note,
  });

  final int port;
  final bool tcpOpen;
  final PortScanCategory category;
  final String? url;
  final String? scheme;
  final String? title;
  final int? statusCode;
  final String? server;
  final String? note;

  bool get isWeb => category != PortScanCategory.openPort;

  String get displayTitle {
    final String? value = title?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return isWeb ? 'Web 服务' : '端口 $port';
  }

  String get detailLabel {
    final List<String> parts = <String>[];
    if (statusCode != null) {
      parts.add('HTTP $statusCode');
    }
    if (server != null && server!.isNotEmpty) {
      parts.add(server!);
    }
    if (!isWeb && note != null && note!.isNotEmpty) {
      parts.add('TCP 已开放，未获得 HTTP 响应');
    }
    return parts.join(' · ');
  }

  DevicePortResult copyWith({String? url, String? scheme, String? title}) {
    return DevicePortResult(
      port: port,
      tcpOpen: tcpOpen,
      category: category,
      url: url ?? this.url,
      scheme: scheme ?? this.scheme,
      title: title ?? this.title,
      statusCode: statusCode,
      server: server,
      note: note,
    );
  }
}

class DevicePortScanProgress {
  const DevicePortScanProgress({
    required this.message,
    this.completed = 0,
    this.total = 0,
  });

  final String message;
  final int completed;
  final int total;

  double get ratio => total <= 0 ? 0 : (completed / total).clamp(0, 1);
}

class DevicePortScanReport {
  const DevicePortScanReport({
    required this.host,
    required this.results,
    required this.duration,
    required this.cancelled,
    required this.errors,
  });

  final String host;
  final List<DevicePortResult> results;
  final Duration duration;
  final bool cancelled;
  final List<String> errors;

  int get confirmedCount =>
      results.where((DevicePortResult r) => r.isWeb).length;
}

/// Phase 2: scan only one device address for common web ports.
class DevicePortScanner {
  DevicePortScanner();

  static const List<int> defaultPorts = <int>[
    80,
    443,
    8000,
    8080,
    8443,
    3000,
    5000,
    5001,
    9090,
    9443,
    8096,
    8920,
    9000,
    9091,
    8989,
  ];

  static const Duration _tcpTimeout = Duration(milliseconds: 550);

  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<DevicePortScanReport> scan(
    String host, {
    List<int> ports = defaultPorts,
    required ValueChanged<DevicePortScanProgress> onProgress,
  }) async {
    _cancelled = false;
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<int> openPorts = <int>[];
    int next = 0;
    int completed = 0;

    Future<void> tcpWorker() async {
      while (!_cancelled) {
        final int index = next++;
        if (index >= ports.length) {
          return;
        }
        final int port = ports[index];
        try {
          final Socket socket = await Socket.connect(
            host,
            port,
            timeout: _tcpTimeout,
          );
          socket.destroy();
          openPorts.add(port);
        } on Object {
          // Closed or filtered.
        }
        completed++;
        onProgress(
          DevicePortScanProgress(
            message: '正在检测 $host:$port',
            completed: completed,
            total: ports.length,
          ),
        );
      }
    }

    await Future.wait(List<Future<void>>.generate(8, (_) => tcpWorker()));

    if (_cancelled) {
      return DevicePortScanReport(
        host: host,
        results: const <DevicePortResult>[],
        duration: stopwatch.elapsed,
        cancelled: true,
        errors: const <String>[],
      );
    }

    openPorts.sort();
    onProgress(
      DevicePortScanProgress(
        message: '正在验证 ${openPorts.length} 个开放端口的 HTTP / HTTPS',
        completed: 0,
        total: openPorts.length,
      ),
    );

    final List<DevicePortResult> results = <DevicePortResult>[];
    int verified = 0;
    int resultIndex = 0;

    Future<void> httpWorker() async {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..idleTimeout = const Duration(seconds: 2)
        ..userAgent = 'LANDeck/0.6 (device service scan)'
        ..badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) => true;
      try {
        while (!_cancelled) {
          final int index = resultIndex++;
          if (index >= openPorts.length) {
            return;
          }
          final int port = openPorts[index];
          final bool preferHttps = _preferHttps(port);
          final List<bool> schemes = preferHttps
              ? <bool>[true, false]
              : <bool>[false, true];
          DevicePortResult? result;
          for (final bool https in schemes) {
            try {
              final Uri uri = Uri.parse(buildScanUrl(host, port, https: https));
              final HttpClientRequest request = await client
                  .getUrl(uri)
                  .timeout(const Duration(seconds: 3));
              request.followRedirects = true;
              request.maxRedirects = 3;
              request.headers.set(
                HttpHeaders.acceptHeader,
                'text/html,application/xhtml+xml,*/*;q=0.8',
              );
              final HttpClientResponse response = await request.close().timeout(
                const Duration(seconds: 4),
              );
              final List<int> bytes = <int>[];
              try {
                await for (final List<int> chunk in response.timeout(
                  const Duration(seconds: 4),
                )) {
                  bytes.addAll(chunk);
                  if (bytes.length >= 65536) {
                    break;
                  }
                }
              } on Object {
                // Keep the response even if the body stalls.
              }
              final String body = utf8.decode(bytes, allowMalformed: true);
              final int status = response.statusCode;
              result = DevicePortResult(
                port: port,
                tcpOpen: true,
                category: status >= 500
                    ? PortScanCategory.candidate
                    : (https
                          ? PortScanCategory.confirmedHttps
                          : PortScanCategory.confirmedHttp),
                url: uri.toString(),
                scheme: https ? 'https' : 'http',
                title: extractHtmlTitle(body),
                statusCode: response.statusCode,
                server: response.headers.value(HttpHeaders.serverHeader),
              );
              break;
            } on Object {
              // Try the other scheme.
            }
          }
          results.add(
            result ??
                DevicePortResult(
                  port: port,
                  tcpOpen: true,
                  category: PortScanCategory.openPort,
                  url: buildScanUrl(host, port, https: preferHttps),
                  scheme: preferHttps ? 'https' : 'http',
                  note: 'TCP 端口开放，但未获得 HTTP / HTTPS 响应',
                ),
          );
          verified++;
          onProgress(
            DevicePortScanProgress(
              message: '已验证 $host:$port',
              completed: verified,
              total: openPorts.length,
            ),
          );
        }
      } finally {
        client.close(force: true);
      }
    }

    await Future.wait(List<Future<void>>.generate(6, (_) => httpWorker()));

    results.sort((DevicePortResult a, DevicePortResult b) {
      if (a.isWeb != b.isWeb) {
        return a.isWeb ? -1 : 1;
      }
      return a.port.compareTo(b.port);
    });
    stopwatch.stop();
    return DevicePortScanReport(
      host: host,
      results: results,
      duration: stopwatch.elapsed,
      cancelled: _cancelled,
      errors: const <String>[],
    );
  }

  bool _preferHttps(int port) {
    return port == 443 ||
        port == 8443 ||
        port == 9443 ||
        port == 5001 ||
        port == 8920;
  }
}
