/// Where a scan candidate came from.
enum ScanSource { mdns, ssdp, port }

extension ScanSourceLabels on ScanSource {
  String get label => switch (this) {
    ScanSource.mdns => 'mDNS',
    ScanSource.ssdp => 'SSDP',
    ScanSource.port => '端口探测',
  };
}

/// How strongly a candidate was confirmed as a web service.
enum ScanConfidence { confirmed, candidate }

/// A real discovery result. It is temporary and is never written to the
/// service table until the user confirms it in the add-service form.
class ScanCandidate {
  const ScanCandidate({
    required this.id,
    required this.host,
    required this.port,
    required this.url,
    required this.sources,
    required this.confidence,
    this.title,
    this.statusCode,
    this.server,
    this.serviceType,
    this.note,
  });

  final String id;
  final String host;
  final int port;
  final String url;
  final Set<ScanSource> sources;
  final ScanConfidence confidence;
  final String? title;
  final int? statusCode;
  final String? server;
  final String? serviceType;
  final String? note;

  bool get isConfirmed => confidence == ScanConfidence.confirmed;

  String get displayTitle {
    final String? value = title?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    return port == 80 || port == 443 ? host : '$host:$port';
  }

  String get sourceLabel => sources.map((ScanSource s) => s.label).join(' · ');

  String get confidenceLabel => isConfirmed ? '已确认' : '候选服务';

  String get detailLabel {
    final List<String> parts = <String>[];
    if (statusCode != null) {
      parts.add('HTTP $statusCode');
    }
    if (serviceType != null && serviceType!.isNotEmpty) {
      parts.add(serviceType!);
    }
    if (server != null && server!.isNotEmpty) {
      parts.add(server!);
    }
    return parts.join(' · ');
  }
}

/// Network information shown before the scan and stored in the report.
class LanNetworkInfo {
  const LanNetworkInfo({
    required this.interfaceName,
    required this.ipAddress,
    required this.prefixLength,
    required this.subnetMask,
    this.gateway,
  });

  final String interfaceName;
  final String ipAddress;
  final int prefixLength;
  final String subnetMask;
  final String? gateway;

  String get cidr => '$ipAddress/$prefixLength';

  int get usableHostCount {
    if (prefixLength >= 31) {
      return prefixLength == 32 ? 1 : 2;
    }
    return (1 << (32 - prefixLength)) - 2;
  }

  String get rangeLabel {
    final int mask = prefixLength == 0
        ? 0
        : (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
    final List<int> parts = ipAddress.split('.').map(int.parse).toList();
    final int ip =
        (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
    final int network = ip & mask;
    final int broadcast = network | (~mask & 0xFFFFFFFF);
    String fmt(int value) =>
        '${(value >> 24) & 255}.${(value >> 16) & 255}.${(value >> 8) & 255}.${value & 255}';
    return '${fmt(network)} – ${fmt(broadcast)}';
  }
}
