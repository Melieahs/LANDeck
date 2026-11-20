import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/url_utils.dart';
import '../../models/scan_candidate.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/lan_scanner.dart';
import '../../services/network_inspector.dart';
import '../services/service_editor_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final NetworkInspector _inspector = const NetworkInspector();
  LanScanner? _scanner;

  LanNetworkInfo? _network;
  String? _networkError;
  bool _loadingNetwork = true;
  bool _scanning = false;
  bool _permissionDenied = false;
  bool _cancelRequested = false;
  ScanProgress? _progress;
  LanScanResult? _result;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  Future<void> _loadNetwork({bool requestPermission = false}) async {
    setState(() {
      _loadingNetwork = true;
      _networkError = null;
    });
    if (requestPermission && !await _ensurePermission()) {
      if (mounted) {
        setState(() => _loadingNetwork = false);
      }
      return;
    }
    try {
      final LanNetworkInfo info = await _inspector.inspect();
      if (!mounted) {
        return;
      }
      setState(() {
        _network = info;
        _networkError = null;
        _loadingNetwork = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _networkError = error.toString();
        _network = null;
        _loadingNetwork = false;
      });
    }
  }

  Future<bool> _ensurePermission() async {
    if (kIsWeb) {
      setState(() {
        _permissionDenied = true;
        _networkError = '网页版无法扫描局域网，请安装 Android APK';
      });
      return false;
    }
    try {
      final PermissionStatus current = await Permission.nearbyWifiDevices.status;
      if (current.isGranted || current.isLimited) {
        if (mounted && _permissionDenied) {
          setState(() => _permissionDenied = false);
        }
        return true;
      }
      if (current.isPermanentlyDenied) {
        if (mounted) {
          setState(() => _permissionDenied = true);
        }
        return false;
      }
      if (!mounted) {
        return false;
      }
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('需要局域网访问权限'),
          content: const Text(
            'LANDeck 需要读取当前 Wi-Fi 网络信息，并访问本机网段来发现局域网中的 Web 服务。\n\n'
            '该权限仅用于附近设备与局域网通信，不会读取位置，也不会扫描公网。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return false;
      }
      final PermissionStatus result =
          await Permission.nearbyWifiDevices.request();
      if (!mounted) {
        return false;
      }
      setState(() {
        _permissionDenied = !result.isGranted && !result.isLimited;
      });
      return result.isGranted || result.isLimited;
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _scanError = '权限请求失败：$error';
        });
      }
      return false;
    }
  }

  Future<void> _retryPermission() async {
    if (await _ensurePermission()) {
      await _loadNetwork();
    }
  }

  Future<void> _startScan() async {
    if (_scanning) {
      return;
    }
    if (!await _ensurePermission()) {
      return;
    }
    if (!mounted) {
      return;
    }
    LanNetworkInfo? network = _network;
    if (network == null) {
      await _loadNetwork();
      network = _network;
    }
    if (network == null || !mounted) {
      return;
    }
    if (network.usableHostCount > 254) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('网段较大'),
          content: Text(
            '当前网段 ${network!.cidr} 约有 ${network.usableHostCount} 台主机。'
            '扫描会控制并发，但仍可能需要 1–2 分钟。\n\n'
            '扫描只在当前 Wi-Fi 网段内进行，可随时取消。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('开始扫描'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    final LanScanner scanner = LanScanner();
    _scanner = scanner;
    setState(() {
      _scanning = true;
      _cancelRequested = false;
      _scanError = null;
      _result = null;
      _progress = const ScanProgress(
        phase: 'mdns',
        message: '正在准备扫描…',
      );
    });

    try {
      final LanScanResult result = await scanner.scan(
        network,
        onProgress: (ScanProgress progress) {
          if (!mounted) {
            return;
          }
          setState(() => _progress = progress);
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _scanning = false;
        _cancelRequested = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
        _scanError = '扫描失败：$error';
      });
    } finally {
      _scanner = null;
    }
  }

  void _cancelScan() {
    _scanner?.cancel();
    setState(() => _cancelRequested = true);
  }

  Future<void> _addCandidate(ScanCandidate candidate) async {
    final LanDeckRepository repository = AppScope.of(context);
    final Uri? uri = Uri.tryParse(candidate.url);
    final String? matchedDeviceId =
        uri == null ? null : repository.findDeviceForHost(uri.host)?.id;
    final Service? saved = await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => ServiceEditorPage(
          candidate: candidate,
          initialDeviceId: matchedDeviceId,
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加「${saved.name}」到服务列表')),
      );
    }
  }

  bool _isAdded(LanDeckRepository repository, ScanCandidate candidate) {
    final String key = canonicalHttpUrl(candidate.url);
    for (final Service service in repository.services) {
      if (canonicalHttpUrl(service.url) == key) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Text(
                '发现',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '扫描当前 Wi-Fi 网段，发现真实的局域网 Web 服务',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _NetworkCard(
                network: _network,
                error: _networkError,
                loading: _loadingNetwork,
                onReload: () => _loadNetwork(requestPermission: true),
              ),
              if (_permissionDenied) ...<Widget>[
                const SizedBox(height: 12),
                _PermissionDeniedBanner(
                  onOpenSettings: openAppSettings,
                  onRetry: _retryPermission,
                ),
              ],
              const SizedBox(height: 12),
              _ScanControlCard(
                scanning: _scanning,
                cancelRequested: _cancelRequested,
                progress: _progress,
                canScan:
                    _network != null && !_loadingNetwork && !_permissionDenied,
                onScan: _startScan,
                onCancel: _cancelScan,
                result: _result,
                error: _scanError,
              ),
              if (_result != null && !_result!.cancelled) ...<Widget>[
                const SizedBox(height: 20),
                _ResultsHeader(result: _result!),
                const SizedBox(height: 8),
                if (_result!.candidates.isEmpty)
                  _NoResults(onRescan: _startScan)
                else
                  ..._result!.candidates.map(
                    (ScanCandidate candidate) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CandidateCard(
                        candidate: candidate,
                        added: _isAdded(repository, candidate),
                        onAdd: () => _addCandidate(candidate),
                      ),
                    ),
                  ),
              ],
              if (_result?.cancelled == true) ...<Widget>[
                const SizedBox(height: 16),
                const _InfoNotice(
                  icon: Icons.stop_circle_outlined,
                  text: '扫描已取消，未保留部分结果。你可以随时重新扫描。',
                ),
              ],
              if (_result?.errors.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 12),
                _ScanErrors(errors: _result!.errors),
              ],
              const SizedBox(height: 12),
              const _InfoNotice(
                icon: Icons.shield_outlined,
                text: '仅扫描当前局域网，不访问公网。扫描结果只是候选，'
                    '确认后才会写入服务列表。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.error,
    required this.loading,
    required this.onReload,
  });

  final LanNetworkInfo? network;
  final String? error;
  final bool loading;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.wifi_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前网络',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: '重新获取',
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
            if (loading) ...<Widget>[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (error != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                error!,
                style: TextStyle(color: scheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新获取'),
              ),
            ] else if (network != null) ...<Widget>[
              const SizedBox(height: 6),
              _InfoRow(label: '接口', value: network!.interfaceName),
              _InfoRow(label: 'IPv4', value: network!.ipAddress),
              _InfoRow(label: '子网掩码', value: network!.subnetMask),
              _InfoRow(label: 'CIDR', value: network!.cidr),
              _InfoRow(label: '扫描范围', value: network!.rangeLabel),
              _InfoRow(label: '可用主机', value: '${network!.usableHostCount} 台'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedBanner extends StatelessWidget {
  const _PermissionDeniedBanner({
    required this.onOpenSettings,
    required this.onRetry,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未授予「附近设备」权限',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '扫描和读取 Wi-Fi 网段需要该权限。可以在系统设置中授权，或重试。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('系统设置'),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('重试'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanControlCard extends StatelessWidget {
  const _ScanControlCard({
    required this.scanning,
    required this.cancelRequested,
    required this.progress,
    required this.canScan,
    required this.onScan,
    required this.onCancel,
    required this.result,
    required this.error,
  });

  final bool scanning;
  final bool cancelRequested;
  final ScanProgress? progress;
  final bool canScan;
  final VoidCallback onScan;
  final VoidCallback onCancel;
  final LanScanResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  scanning ? Icons.radar_rounded : Icons.travel_explore_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scanning ? '正在扫描' : '局域网扫描',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (result != null && !scanning)
                  Text(
                    '${result!.candidates.length} 个结果',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            if (scanning) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress?.ratio == 0 ? null : progress?.ratio,
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Text(
                progress?.message ?? '正在准备扫描…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (progress != null && progress!.total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${progress!.completed} / ${progress!.total}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: cancelRequested ? null : onCancel,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(cancelRequested ? '正在取消…' : '取消扫描'),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '扫描 mDNS、SSDP，并探测当前网段的常见 Web 端口。'
                '只使用当前网络，不会扫描公网。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canScan ? onScan : null,
                icon: const Icon(Icons.search_rounded),
                label: const Text('开始扫描'),
              ),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.result});

  final LanScanResult result;

  @override
  Widget build(BuildContext context) {
    final int confirmed =
        result.candidates.where((ScanCandidate c) => c.isConfirmed).length;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '扫描结果',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          '$confirmed 已确认 · mDNS ${result.mdnsCount} · SSDP ${result.ssdpCount}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.added,
    required this.onAdd,
  });

  final ScanCandidate candidate;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: added ? null : onAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                candidate.isConfirmed
                    ? Icons.verified_rounded
                    : Icons.help_outline_rounded,
                color: candidate.isConfirmed
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      candidate.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      candidate.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _MiniChip(text: candidate.confidenceLabel),
                        _MiniChip(text: candidate.sourceLabel),
                        if (candidate.detailLabel.isNotEmpty)
                          _MiniChip(text: candidate.detailLabel),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              added
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('已添加'),
                    )
                  : FilledButton.tonal(
                      onPressed: onAdd,
                      child: const Text('添加'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onRescan});

  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: ListTile(
        leading: const Icon(Icons.search_off_rounded),
        title: const Text('没有发现服务'),
        subtitle: const Text('确认设备在线，或稍后重新扫描。'),
        trailing: TextButton(
          onPressed: onRescan,
          child: const Text('重新扫描'),
        ),
      ),
    );
  }
}

class _ScanErrors extends StatelessWidget {
  const _ScanErrors({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: ExpansionTile(
        leading: Icon(Icons.info_outline_rounded, color: scheme.error),
        title: Text('部分发现方式未完成（${errors.length}）'),
        children: errors
            .map(
              (String error) => ListTile(
                dense: true,
                title: Text(error),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
