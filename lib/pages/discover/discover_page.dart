import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
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
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '发现',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '扫描当前 Wi-Fi 网段，发现真实的局域网 Web 服务',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                _NetworkCard(
                  network: _network,
                  error: _networkError,
                  loading: _loadingNetwork,
                  permissionDenied: _permissionDenied,
                  onReload: () => _loadNetwork(requestPermission: true),
                  onOpenSettings: openAppSettings,
                ),
                if (_permissionDenied) ...<Widget>[
                  const SizedBox(height: 12),
                  _PermissionDeniedBanner(
                    onOpenSettings: openAppSettings,
                    onRetry: _retryPermission,
                  ),
                ],
                const SizedBox(height: 14),
                _ScanControlCard(
                  scanning: _scanning,
                  cancelRequested: _cancelRequested,
                  progress: _progress,
                  canScan: _network != null &&
                      !_loadingNetwork &&
                      !_permissionDenied,
                  onScan: _startScan,
                  onCancel: _cancelScan,
                  result: _result,
                  error: _scanError,
                ),
                if (_result != null && !_result!.cancelled) ...<Widget>[
                  const SizedBox(height: 22),
                  _ResultsHeader(result: _result!),
                  const SizedBox(height: 10),
                  if (_result!.candidates.isEmpty)
                    _NoResults(onRescan: _startScan)
                  else
                    ..._result!.candidates.map(
                      (ScanCandidate candidate) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CandidateCard(
                          candidate: candidate,
                          added: _isAdded(repository, candidate),
                          onAdd: () => _addCandidate(candidate),
                        ),
                      ),
                    ),
                ],
                if (_result?.cancelled == true) ...<Widget>[
                  const SizedBox(height: 22),
                  const _InfoNotice(
                    icon: Icons.stop_circle_outlined,
                    text: '扫描已取消，未保留部分结果。你可以随时重新扫描。',
                  ),
                ],
                const SizedBox(height: 20),
                const _InfoNotice(
                  icon: Icons.privacy_tip_outlined,
                  text: '扫描只访问当前 Wi-Fi 网段，不访问公网。'
                      '发现结果不会自动保存，只有你确认添加后才会写入本机数据库。',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedBanner extends StatelessWidget {
  const _PermissionDeniedBanner({
    required this.onOpenSettings,
    required this.onRetry,
  });

  final Future<bool> Function() onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.offline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  '未授予「附近设备」权限',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onOpenSettings(),
                child: const Text('系统设置'),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '系统阻止了 Wi-Fi 信息与局域网扫描权限。请在系统设置中允许 LANDeck 访问附近设备后重试。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.error,
    required this.loading,
    required this.permissionDenied,
    required this.onReload,
    required this.onOpenSettings,
  });

  final LanNetworkInfo? network;
  final String? error;
  final bool loading;
  final bool permissionDenied;
  final VoidCallback onReload;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  '当前网络',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else if (network != null)
                Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '已连接',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.online,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  '不可用',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (network != null) ...<Widget>[
            const SizedBox(height: 14),
            _NetworkRow(label: '网络接口', value: network!.interfaceName),
            _NetworkRow(label: 'IPv4 地址', value: network!.ipAddress),
            _NetworkRow(
              label: '子网掩码',
              value: '${network!.subnetMask}  ·  /${network!.prefixLength}',
            ),
            _NetworkRow(label: '扫描范围', value: network!.rangeLabel),
            _NetworkRow(
              label: '可探测主机',
              value: '${network!.usableHostCount} 台',
              last: true,
            ),
          ] else if (!loading) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              error ?? '无法获取网络信息',
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onReload,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('重新获取'),
                ),
                if (permissionDenied) ...<Widget>[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onOpenSettings,
                    child: const Text('打开系统设置'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
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

  String get _phaseLabel {
    return switch (progress?.phase) {
      'mdns' => 'mDNS 发现',
      'ssdp' => 'SSDP 发现',
      'tcp' => '端口探测',
      'verify' => 'Web 服务验证',
      'done' => '扫描完成',
      _ => '局域网扫描',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '真实扫描',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!scanning)
                FilledButton.icon(
                  onPressed: canScan ? onScan : null,
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: Text(result == null ? '开始扫描' : '重新扫描'),
                ),
            ],
          ),
          if (scanning) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    cancelRequested ? '正在取消…' : _phaseLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: cancelRequested ? null : onCancel,
                  icon: const Icon(Icons.stop_rounded, size: 15),
                  label: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: (progress?.total ?? 0) > 0 ? progress!.ratio : null,
                backgroundColor: AppColors.surfaceHigh,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progress?.message ?? '正在准备扫描…',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if ((progress?.total ?? 0) > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${progress!.completed} / ${progress!.total}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ] else if (result == null && error == null) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              '使用 mDNS、SSDP 与常见 Web 端口探测，并对开放端口发送 HTTP / HTTPS 请求确认页面。'
              '只有检测到真实响应的地址才会成为结果。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.65,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const _InfoNotice(
              icon: Icons.speed_rounded,
              text: '扫描不会访问公网，也不会自动添加任何服务。',
            ),
          ],
          if (error != null && !scanning) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.offline,
              ),
            ),
          ],
          if (result != null && !scanning) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _CountPill(label: '结果', value: '${result!.candidates.length}'),
                const SizedBox(width: 7),
                _CountPill(label: 'mDNS', value: '${result!.mdnsCount}'),
                const SizedBox(width: 7),
                _CountPill(label: 'SSDP', value: '${result!.ssdpCount}'),
                const Spacer(),
                Text(
                  '${result!.duration.inSeconds}s',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            if (result!.errors.isNotEmpty) ...<Widget>[
              const SizedBox(height: 9),
              Text(
                result!.errors.take(2).join('\n'),
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textMuted,
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Text(
          '扫描结果',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$confirmed 个已确认 · ${result.candidates.length} 条结果',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
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
    final bool confirmed = candidate.isConfirmed;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: confirmed
                  ? AppColors.accentSoft
                  : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              confirmed ? Icons.public_rounded : Icons.help_outline_rounded,
              size: 19,
              color: confirmed ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        candidate.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: confirmed
                            ? AppColors.surfaceSoft
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        candidate.confidenceLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: confirmed
                              ? AppColors.online
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.accent,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  <String>[
                    candidate.sourceLabel,
                    if (candidate.detailLabel.isNotEmpty) candidate.detailLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                if (!confirmed) ...<Widget>[
                  const SizedBox(height: 2),
                  const Text(
                    '端口开放，但未确认 HTTP 响应',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (added)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.online,
                  ),
                  SizedBox(width: 3),
                  Text(
                    '已添加',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.online,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              key: ValueKey<String>('scan-add-${candidate.id}'),
              onPressed: onAdd,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                backgroundColor: AppColors.accentSoft,
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                '添加',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onRescan});

  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.search_off_rounded,
            size: 30,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 9),
          const Text(
            '未发现可访问的 Web 服务',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '确认设备与手机在同一 Wi-Fi、目标服务已启动，然后重试。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRescan,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('重新扫描'),
          ),
        ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
