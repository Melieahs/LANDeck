import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../models/discovered_device.dart';
import '../../models/scan_candidate.dart';
import '../../repositories/service_repository.dart';
import '../../services/device_discovery.dart';
import '../../services/network_inspector.dart';
import '../../widgets/service_icon.dart';
import '../devices/device_detail_page.dart';
import '../devices/device_editor_page.dart';

/// Phase 1 of LAN discovery: find devices only. Service ports are scanned
/// later from a specific device, never across the whole subnet.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final NetworkInspector _inspector = const NetworkInspector();
  DeviceDiscoveryService? _discovery;

  LanNetworkInfo? _network;
  String? _networkError;
  bool _loadingNetwork = true;
  bool _discovering = false;
  bool _permissionDenied = false;
  bool _cancelRequested = false;
  DeviceDiscoveryProgress? _progress;
  DeviceDiscoveryResult? _result;
  String? _discoveryError;
  final Set<String> _selected = <String>{};

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
      final PermissionStatus current =
          await Permission.nearbyWifiDevices.status;
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
          icon: const Icon(Icons.wifi_tethering_rounded),
          title: const Text('需要局域网访问权限'),
          content: const Text(
            'LANDeck 需要读取当前 Wi-Fi 网络信息，并访问本机网段来发现局域网设备。\n\n'
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
      final PermissionStatus result = await Permission.nearbyWifiDevices
          .request();
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
          _discoveryError = '权限请求失败：$error';
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

  Future<void> _startDiscovery() async {
    if (_discovering) {
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
          icon: const Icon(Icons.hub_outlined),
          title: const Text('网段较大'),
          content: Text(
            '当前网段 ${network!.cidr} 约有 ${network.usableHostCount} 台主机。'
            '发现过程会控制并发，但仍可能需要一段时间。\n\n'
            '只会在当前 Wi-Fi 网段内发现设备，可随时取消。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('开始发现'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    final DeviceDiscoveryService discovery = DeviceDiscoveryService();
    _discovery = discovery;
    setState(() {
      _discovering = true;
      _cancelRequested = false;
      _discoveryError = null;
      _result = null;
      _selected.clear();
      _progress = const DeviceDiscoveryProgress(
        phase: 'mdns',
        message: '正在准备发现设备…',
      );
    });

    try {
      final DeviceDiscoveryResult result = await discovery.scan(
        network,
        onProgress: (DeviceDiscoveryProgress progress) {
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
        _discovering = false;
        _cancelRequested = false;
        _selected.removeWhere(
          (String ip) => result.devices.every(
            (DiscoveredDevice device) => device.ipAddress != ip,
          ),
        );
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _discovering = false;
        _discoveryError = '发现设备失败：$error';
      });
    } finally {
      _discovery = null;
    }
  }

  void _cancelDiscovery() {
    _discovery?.cancel();
    setState(() => _cancelRequested = true);
  }

  Future<void> _openAddDevice(
    DiscoveredDevice discovered,
    LanDeckRepository repository,
  ) async {
    final Device? existing = repository.findDeviceForHost(discovered.ipAddress);
    if (existing != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              DeviceDetailPage(deviceId: existing.id),
        ),
      );
      return;
    }
    final Device? saved = await Navigator.of(context).push<Device>(
      MaterialPageRoute<Device>(
        builder: (BuildContext context) => DeviceEditorPage(
          initialName: _suggestedName(discovered),
          initialAddress: discovered.ipAddress,
          initialType: discovered.deviceTypeHint ?? DeviceType.other,
        ),
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    setState(() => _selected.remove(discovered.ipAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加设备「${saved.name}」')),
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DeviceDetailPage(deviceId: saved.id),
      ),
    );
  }

  String _suggestedName(DiscoveredDevice discovered) {
    final String name = discovered.displayName.trim();
    if (name.isNotEmpty && name != discovered.ipAddress) {
      return name;
    }
    return '设备 ${discovered.ipAddress}';
  }

  Future<void> _addSelected(LanDeckRepository repository) async {
    final DeviceDiscoveryResult? result = _result;
    if (result == null || _selected.isEmpty) {
      return;
    }
    int added = 0;
    int skipped = 0;
    final List<String> failures = <String>[];
    for (final DiscoveredDevice discovered in result.devices) {
      if (!_selected.contains(discovered.ipAddress)) {
        continue;
      }
      if (repository.findDeviceForHost(discovered.ipAddress) != null) {
        skipped++;
        continue;
      }
      try {
        await repository.addDevice(
          name: _suggestedName(discovered),
          deviceType: discovered.deviceTypeHint ?? DeviceType.other,
          primaryAddress: discovered.ipAddress,
        );
        added++;
      } on Object catch (error) {
        failures.add('${discovered.ipAddress}: $error');
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _selected.clear());
    final String message = failures.isEmpty
        ? '已添加 $added 台设备${skipped > 0 ? '，跳过 $skipped 台已存在' : ''}'
        : '已添加 $added 台，${failures.length} 台失败';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final DeviceDiscoveryResult? result = _result;
    final bool hasResults = result != null && !result.cancelled;
    final int existingCount = result == null
        ? 0
        : result.devices
              .where(
                (DiscoveredDevice device) =>
                    repository.findDeviceForHost(device.ipAddress) != null,
              )
              .length;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Text('发现设备', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '第一阶段只发现局域网设备，不扫描全部服务端口',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
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
              _DiscoveryControlCard(
                discovering: _discovering,
                cancelRequested: _cancelRequested,
                progress: _progress,
                canStart:
                    _network != null && !_loadingNetwork && !_permissionDenied,
                onStart: _startDiscovery,
                onCancel: _cancelDiscovery,
                result: result,
              ),
              if (hasResults) ...<Widget>[
                const SizedBox(height: 20),
                _ResultsHeader(
                  total: result.devices.length,
                  existing: existingCount,
                  result: result,
                ),
                if (result.devices.isEmpty)
                  _NoResults(onRescan: _startDiscovery)
                else ...<Widget>[
                  const SizedBox(height: 8),
                  _SelectionBar(
                    count: _selected.length,
                    onClear: () => setState(() => _selected.clear()),
                    onAdd: () => _addSelected(repository),
                  ),
                  for (final DiscoveredDevice discovered in result.devices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DeviceCandidateCard(
                        discovered: discovered,
                        existing: repository.findDeviceForHost(
                          discovered.ipAddress,
                        ),
                        selected: _selected.contains(discovered.ipAddress),
                        onSelected: (bool value) {
                          setState(() {
                            if (value) {
                              _selected.add(discovered.ipAddress);
                            } else {
                              _selected.remove(discovered.ipAddress);
                            }
                          });
                        },
                        onAdd: () => _openAddDevice(discovered, repository),
                      ),
                    ),
                ],
              ],
              if (result?.cancelled == true) ...<Widget>[
                const SizedBox(height: 16),
                const _InfoNotice(
                  icon: Icons.stop_circle_outlined,
                  text: '发现已取消，未保留部分结果。你可以随时重新发现。',
                ),
              ],
              if (result?.errors.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 12),
                _DiscoveryErrors(errors: result!.errors),
              ],
              if (_discoveryError != null) ...<Widget>[
                const SizedBox(height: 12),
                _ErrorNotice(message: _discoveryError!),
              ],
              const SizedBox(height: 12),
              const _InfoNotice(
                icon: Icons.devices_other_outlined,
                text:
                    '只显示当前局域网中真实发现的设备。活跃主机不会自动被识别为 NAS 或路由器；'
                    '设备名称、类型可添加前修改。扫描结果不会自动写入数据库。',
              ),
              const SizedBox(height: 8),
              const _InfoNotice(
                icon: Icons.manage_search_rounded,
                text: '服务的端口扫描在设备详情页进行，只针对该设备的地址，避免全网端口扫描。',
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
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.wifi_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('当前网络', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else if (network != null) ...<Widget>[
                    Text(
                      '${network!.interfaceName} · ${network!.ipAddress}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${network!.subnetMask}  ·  ${network!.cidr}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '范围 ${network!.rangeLabel} · ${network!.usableHostCount} 台主机',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ] else
                    Text(
                      error ?? '无法获取当前 Wi-Fi 网络信息',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '重新获取网络信息',
              onPressed: loading ? null : onReload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryControlCard extends StatelessWidget {
  const _DiscoveryControlCard({
    required this.discovering,
    required this.cancelRequested,
    required this.progress,
    required this.canStart,
    required this.onStart,
    required this.onCancel,
    required this.result,
  });

  final bool discovering;
  final bool cancelRequested;
  final DeviceDiscoveryProgress? progress;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final DeviceDiscoveryResult? result;

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
                Expanded(
                  child: Text(
                    discovering ? '正在发现设备' : '发现局域网设备',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (discovering)
                  TextButton.icon(
                    onPressed: cancelRequested ? null : onCancel,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(cancelRequested ? '正在取消…' : '取消'),
                  )
                else
                  FilledButton.icon(
                    key: const ValueKey<String>('discover-start'),
                    onPressed: canStart ? onStart : null,
                    icon: const Icon(Icons.radar_rounded),
                    label: Text(result == null ? '开始发现' : '重新发现'),
                  ),
              ],
            ),
            if (discovering) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress?.ratio == 0 ? null : progress?.ratio,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                progress?.message ?? '正在准备…',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'mDNS / SSDP 优先，主机发现补充。不会在第一阶段扫描服务端口。',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.total,
    required this.existing,
    required this.result,
  });

  final int total;
  final int existing;
  final DeviceDiscoveryResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('发现结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '$total',
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const Spacer(),
            if (existing > 0)
              Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 16),
                label: Text('已添加 $existing'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'mDNS ${result.mdnsCount} · SSDP ${result.ssdpCount} · '
          '主机 ${result.hostCount} · ${result.duration.inSeconds}s',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onAdd,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('已选 $count 台设备')),
              TextButton(onPressed: onClear, child: const Text('清除')),
              FilledButton.tonal(
                key: const ValueKey<String>('discover-add-selected'),
                onPressed: onAdd,
                child: const Text('添加所选'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCandidateCard extends StatelessWidget {
  const _DeviceCandidateCard({
    required this.discovered,
    required this.existing,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
  });

  final DiscoveredDevice discovered;
  final Device? existing;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool added = existing != null;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: added ? onAdd : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: added || selected,
                onChanged: added
                    ? null
                    : (bool? value) => onSelected(value ?? false),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ServiceIconBadge(
                  icon: iconForDeviceType(
                    discovered.deviceTypeHint ?? DeviceType.other,
                  ),
                  size: 42,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            discovered.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (added)
                          Chip(
                            label: const Text('已添加'),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${discovered.ipAddress} · ${discovered.typeLabel}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '来源：${discovered.sourceLabel}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (discovered.detailLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        discovered.detailLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: added
                    ? TextButton(onPressed: onAdd, child: const Text('查看'))
                    : FilledButton.tonal(
                        key: ValueKey<String>(
                          'discover-add-${discovered.ipAddress}',
                        ),
                        onPressed: onAdd,
                        child: const Text('添加'),
                      ),
              ),
            ],
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '未授予「附近设备」权限',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '无法读取 Wi-Fi 网段或扫描局域网。可在系统设置中授权后重试。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => onOpenSettings(),
              child: const Text('系统设置'),
            ),
            TextButton(
              key: const ValueKey<String>('permission-retry'),
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.devices_other_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text('没有发现设备', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '当前网络可能没有开启 mDNS / SSDP，或设备不响应主机发现。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新发现'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryErrors extends StatelessWidget {
  const _DiscoveryErrors({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline_rounded),
        title: Text('发现过程提示（${errors.length}）'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          for (final String error in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '• $error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          Icons.error_outline_rounded,
          color: scheme.onErrorContainer,
        ),
        title: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
