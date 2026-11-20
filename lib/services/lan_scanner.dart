import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../core/utils/html_utils.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/url_utils.dart';
import '../models/scan_candidate.dart';
import 'multicast_lock.dart';

class _MdnsHint {
  _MdnsHint({
    required this.host,
    required this.port,
    required this.serviceType,
    required this.preferHttps,
  });

  final String host;
  final int port;
  final String serviceType;
  final bool preferHttps;
}

class _HttpInfo {
  _HttpInfo({
    required this.statusCode,
    required this.title,
    required this.server,
  });

  final int statusCode;
  final String? title;
  final String? server;
}

class _CandidateBuilder {
  _CandidateBuilder({required this.host, required this.port});

  final String host;
  final int port;
  final Set<ScanSource> sources = <ScanSource>{};
  String? title;
  int? statusCode;
  String? server;
  String? serviceType;
  String? note;
  bool confirmed = false;
  bool preferHttps = false;
  String? workingUrl;
}

/// Real LAN scanner.
///
/// Layers:
/// 1. mDNS (`_http._tcp`, `_https._tcp`, …) for advertised web services.
/// 2. SSDP M-SEARCH for device hints (never treated as a web service alone).
/// 3. Bounded TCP probe of common web ports on the active subnet.
/// 4. HTTP/HTTPS request to verify a real web response and read its title.
class LanScanner {
  LanScanner();

  static const List<int> commonWebPorts = <int>[
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
    7878,
  ];

  static const List<String> _mdnsTypes = <String>[
    '_http._tcp.local',
    '_https._tcp.local',
    '_workstation._tcp.local',
    '_device-info._tcp.local',
    '_home-assistant._tcp.local',
    '_googlecast._tcp.local',
  ];

  static const int _maxHosts = 512;
  static const int _tcpConcurrency = 64;
  static const Duration _tcpTimeout = Duration(milliseconds: 350);

  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  Future<LanScanResult> scan(
    LanNetworkInfo network, {
    required ValueChanged<ScanProgress> onProgress,
  }) async {
    _cancelled = false;
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> errors = <String>[];
    final List<String> hosts = hostsForCidr(
      network.ipAddress,
      network.prefixLength,
    );
    if (hosts.isEmpty) {
      return LanScanResult(
        network: network,
        candidates: const <ScanCandidate>[],
        errors: const <String>['无法计算扫描范围'],
        cancelled: false,
        duration: stopwatch.elapsed,
        mdnsCount: 0,
        ssdpCount: 0,
      );
    }
    if (hosts.length > _maxHosts) {
      return LanScanResult(
        network: network,
        candidates: const <ScanCandidate>[],
        errors: <String>[
          '网段包含 ${hosts.length} 台主机，超过安全上限 $_maxHosts',
        ],
        cancelled: false,
        duration: stopwatch.elapsed,
        mdnsCount: 0,
        ssdpCount: 0,
      );
    }

    final Set<String> hostSet = hosts.toSet();
    onProgress(
      const ScanProgress(phase: 'mdns', message: '正在通过 mDNS 查询局域网服务'),
    );

    final List<_MdnsHint> mdnsHints = <_MdnsHint>[];
    final MulticastLock lock = MulticastLock();
    await lock.acquire();
    try {
      mdnsHints.addAll(
        await _discoverMdns(hostSet, onProgress).timeout(
          const Duration(seconds: 9),
          onTimeout: () => const <_MdnsHint>[],
        ),
      );
    } on Object catch (error) {
      errors.add('mDNS 查询失败：$error');
    } finally {
      await lock.release();
    }

    if (_cancelled) {
      return _cancelledResult(network, stopwatch, errors, mdnsHints.length, 0);
    }

    onProgress(
      const ScanProgress(phase: 'ssdp', message: '正在通过 SSDP 查找局域网设备'),
    );
    final Map<String, String> ssdpHints = await _discoverSsdp(
      hostSet,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => <String, String>{},
    );
    if (ssdpHints.isEmpty) {
      errors.add('SSDP 未收到响应（不影响端口扫描）');
    }

    if (_cancelled) {
      return _cancelledResult(
        network,
        stopwatch,
        errors,
        mdnsHints.length,
        ssdpHints.length,
      );
    }

    final Set<int> ports = <int>{...commonWebPorts};
    for (final _MdnsHint hint in mdnsHints) {
      ports.add(hint.port);
    }

    onProgress(
      ScanProgress(
        phase: 'tcp',
        message: '正在探测 ${hosts.length} 台主机的 ${ports.length} 个常见 Web 端口',
        completed: 0,
        total: hosts.length * ports.length,
      ),
    );
    final Map<String, List<int>> openPorts = await _probeTargets(
      hosts,
      ports.toList(),
      onProgress,
    );

    if (_cancelled) {
      return _cancelledResult(
        network,
        stopwatch,
        errors,
        mdnsHints.length,
        ssdpHints.length,
      );
    }

    final Map<String, _CandidateBuilder> builders =
        <String, _CandidateBuilder>{};
    _CandidateBuilder ensure(String host, int port) {
      return builders.putIfAbsent(
        '$host:$port',
        () => _CandidateBuilder(host: host, port: port),
      );
    }

    for (final MapEntry<String, List<int>> entry in openPorts.entries) {
      for (final int port in entry.value) {
        ensure(entry.key, port).sources.add(ScanSource.port);
        if (ssdpHints.containsKey(entry.key)) {
          builders['${entry.key}:$port']!.sources.add(ScanSource.ssdp);
        }
      }
    }
    for (final _MdnsHint hint in mdnsHints) {
      final _CandidateBuilder builder = ensure(hint.host, hint.port);
      builder.sources.add(ScanSource.mdns);
      builder.serviceType = hint.serviceType;
      builder.preferHttps = hint.preferHttps;
    }
    for (final String host in ssdpHints.keys) {
      for (final int port in openPorts[host] ?? const <int>[]) {
        ensure(host, port).sources.add(ScanSource.ssdp);
      }
    }

    if (builders.isEmpty) {
      stopwatch.stop();
      onProgress(
        const ScanProgress(phase: 'done', message: '扫描完成，未发现可访问的 Web 服务'),
      );
      return LanScanResult(
        network: network,
        candidates: const <ScanCandidate>[],
        errors: errors,
        cancelled: false,
        duration: stopwatch.elapsed,
        mdnsCount: mdnsHints.length,
        ssdpCount: ssdpHints.length,
      );
    }

    onProgress(
      ScanProgress(
        phase: 'verify',
        message: '正在验证 HTTP / HTTPS 响应',
        completed: 0,
        total: builders.length,
      ),
    );

    final List<_CandidateBuilder> toVerify = builders.values.toList();
    int verified = 0;
    int nextIndex = 0;

    Future<void> verifyWorker() async {
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..idleTimeout = const Duration(seconds: 2)
        ..userAgent = 'LANDeck/0.2 (LAN scanner)'
        ..badCertificateCallback = (
          X509Certificate cert,
          String host,
          int port,
        ) => true;
      try {
        while (!_cancelled) {
          final int index = nextIndex++;
          if (index >= toVerify.length) {
            return;
          }
          final _CandidateBuilder builder = toVerify[index];
          final _MdnsHint? hint = _hintFor(builder.host, builder.port, mdnsHints);
          final bool preferHttps =
              hint?.preferHttps ??
              (builder.preferHttps ||
                  builder.port == 443 ||
                  builder.port == 8443 ||
                  builder.port == 9443 ||
                  builder.port == 5001 ||
                  builder.port == 8920);
          final List<bool> schemes = preferHttps
              ? <bool>[true, false]
              : <bool>[false, true];
          String? lastNote;
          for (final bool https in schemes) {
            try {
              final _HttpInfo info = await _httpProbe(
                client,
                builder.host,
                builder.port,
                https: https,
              );
              builder
                ..confirmed = true
                ..statusCode = info.statusCode
                ..title = info.title
                ..server = info.server
                ..note = null
                ..workingUrl = _urlFor(
                  builder.host,
                  builder.port,
                  https: https,
                );
              break;
            } on Object catch (error) {
              lastNote = error.toString();
            }
          }
          if (!builder.confirmed) {
            builder.note = lastNote;
          }
          verified++;
          onProgress(
            ScanProgress(
              phase: 'verify',
              message: '已验证 ${builder.host}:${builder.port}',
              completed: verified,
              total: toVerify.length,
            ),
          );
        }
      } finally {
        client.close(force: true);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(
        12,
        (int index) => verifyWorker(),
      ),
    );

    final List<ScanCandidate> candidates = builders.values
        .map((_CandidateBuilder builder) => _toCandidate(builder))
        .toList()
      ..sort((ScanCandidate a, ScanCandidate b) {
        if (a.isConfirmed != b.isConfirmed) {
          return a.isConfirmed ? -1 : 1;
        }
        final int host = a.host.compareTo(b.host);
        return host != 0 ? host : a.port.compareTo(b.port);
      });

    stopwatch.stop();
    onProgress(
      ScanProgress(
        phase: 'done',
        message: _cancelled ? '扫描已取消' : '扫描完成，共 ${candidates.length} 条结果',
      ),
    );
    return LanScanResult(
      network: network,
      candidates: candidates,
      errors: errors,
      cancelled: _cancelled,
      duration: stopwatch.elapsed,
      mdnsCount: mdnsHints.length,
      ssdpCount: ssdpHints.length,
    );
  }

  LanScanResult _cancelledResult(
    LanNetworkInfo network,
    Stopwatch stopwatch,
    List<String> errors,
    int mdnsCount,
    int ssdpCount,
  ) {
    stopwatch.stop();
    return LanScanResult(
      network: network,
      candidates: const <ScanCandidate>[],
      errors: errors,
      cancelled: true,
      duration: stopwatch.elapsed,
      mdnsCount: mdnsCount,
      ssdpCount: ssdpCount,
    );
  }

  _MdnsHint? _hintFor(String host, int port, List<_MdnsHint> hints) {
    for (final _MdnsHint hint in hints) {
      if (hint.host == host && hint.port == port) {
        return hint;
      }
    }
    return null;
  }

  ScanCandidate _toCandidate(_CandidateBuilder builder) {
    final String url =
        builder.workingUrl ??
        buildScanUrl(
          builder.host,
          builder.port,
          https: builder.preferHttps,
        );
    return ScanCandidate(
      id: '${builder.host}:${builder.port}',
      host: builder.host,
      port: builder.port,
      url: url,
      sources: builder.sources,
      confidence: builder.confirmed
          ? ScanConfidence.confirmed
          : ScanConfidence.candidate,
      title: builder.title,
      statusCode: builder.statusCode,
      server: builder.server,
      serviceType: builder.serviceType,
      note: builder.note,
    );
  }

  Future<List<_MdnsHint>> _discoverMdns(
    Set<String> hosts,
    ValueChanged<ScanProgress> onProgress,
  ) async {
    final MDnsClient client = MDnsClient();
    final List<_MdnsHint> hints = <_MdnsHint>[];
    try {
      await client.start(
        onError: (Object error) {
          // Ignore socket errors on specific interfaces.
        },
      );
      for (final String type in _mdnsTypes) {
        if (_cancelled) {
          break;
        }
        onProgress(
          ScanProgress(phase: 'mdns', message: 'mDNS 查询 $type'),
        );
        try {
          final PtrResourceRecord ptr = await client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(type),
              )
              .first
              .timeout(const Duration(seconds: 2));
          if (ptr.domainName.isEmpty) {
            continue;
          }
          final SrvResourceRecord srv = await client
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )
              .first
              .timeout(const Duration(seconds: 2));
          if (srv.port <= 0 || srv.port > 65535) {
            continue;
          }
          final IPAddressResourceRecord address = await client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .first
              .timeout(const Duration(seconds: 2));
          final String host = address.address.address;
          if (!hosts.contains(host)) {
            continue;
          }
          hints.add(
            _MdnsHint(
              host: host,
              port: srv.port,
              serviceType: type,
              preferHttps: type.startsWith('_https'),
            ),
          );
        } on Object {
          // A missing type is normal.
        }
      }
    } finally {
      client.stop();
    }
    return hints;
  }

  Future<Map<String, String>> _discoverSsdp(Set<String> hosts) async {
    RawDatagramSocket? socket;
    final Map<String, String> found = <String, String>{};
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
        final String host = datagram.address.address;
        if (!hosts.contains(host)) {
          return;
        }
        final String text = utf8.decode(datagram.data, allowMalformed: true);
        final String? server = _header(text, 'server');
        final String? st = _header(text, 'st');
        found[host] =
            <String?>[server, st].whereType<String>().join(' · ');
      });
      final String message =
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
      // SSDP is optional.
    } finally {
      socket?.close();
    }
    return found;
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

  Future<Map<String, List<int>>> _probeTargets(
    List<String> hosts,
    List<int> ports,
    ValueChanged<ScanProgress> onProgress,
  ) async {
    final List<String> targets = <String>[];
    for (final String host in hosts) {
      for (final int port in ports) {
        targets.add('$host:$port');
      }
    }
    final Map<String, List<int>> open = <String, List<int>>{};
    int nextIndex = 0;
    int completed = 0;

    Future<void> worker() async {
      while (!_cancelled) {
        final int index = nextIndex++;
        if (index >= targets.length) {
          return;
        }
        final String target = targets[index];
        final int split = target.lastIndexOf(':');
        final String host = target.substring(0, split);
        final int port = int.parse(target.substring(split + 1));
        try {
          final Socket socket = await Socket.connect(
            host,
            port,
            timeout: _tcpTimeout,
          );
          socket.destroy();
          open.putIfAbsent(host, () => <int>[]).add(port);
        } on Object {
          // Closed/filtered port.
        }
        completed++;
        if (completed % 25 == 0 || completed == targets.length) {
          onProgress(
            ScanProgress(
              phase: 'tcp',
              message: '已探测 $host',
              completed: completed,
              total: targets.length,
            ),
          );
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(
        _tcpConcurrency,
        (int index) => worker(),
      ),
    );
    return open;
  }

  String _urlFor(String host, int port, {required bool https}) {
    return buildScanUrl(host, port, https: https);
  }

  Future<_HttpInfo> _httpProbe(
    HttpClient client,
    String host,
    int port, {
    required bool https,
  }) async {
    final Uri uri = Uri.parse(_urlFor(host, port, https: https));
    final HttpClientRequest request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 3));
    request.followRedirects = true;
    request.maxRedirects = 3;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/html,application/xhtml+xml,*/*;q=0.8',
    );
    final HttpClientResponse response = await request
        .close()
        .timeout(const Duration(seconds: 4));
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
      // A body timeout still leaves us with a valid HTTP response.
    }
    final String body = utf8.decode(bytes, allowMalformed: true);
    return _HttpInfo(
      statusCode: response.statusCode,
      title: extractHtmlTitle(body),
      server: response.headers.value(HttpHeaders.serverHeader),
    );
  }

  bool isPrivateIPv4(String host) {
    final List<int>? parts = _parseIPv4(host);
    if (parts == null) {
      return false;
    }
    return parts[0] == 10 ||
        (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
        (parts[0] == 192 && parts[1] == 168);
  }

  List<int>? _parseIPv4(String host) {
    final List<String> parts = host.split('.');
    if (parts.length != 4) {
      return null;
    }
    final List<int> values = <int>[];
    for (final String part in parts) {
      final int? value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return null;
      }
      values.add(value);
    }
    return values;
  }
}
