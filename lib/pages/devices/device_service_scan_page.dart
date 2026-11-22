import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/url_utils.dart';
import '../../models/device.dart';
import '../../models/scan_candidate.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/device_port_scanner.dart';
import '../../widgets/service_icon.dart';
import '../services/service_editor_page.dart';

/// Phase 2: scan only the ports of one known device.
class DeviceServiceScanPage extends StatefulWidget {
  const DeviceServiceScanPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<DeviceServiceScanPage> createState() => _DeviceServiceScanPageState();
}

class _DeviceServiceScanPageState extends State<DeviceServiceScanPage> {
  DevicePortScanner? _scanner;
  DevicePortScanReport? _report;
  DevicePortScanProgress? _progress;
  String? _error;
  bool _scanning = false;
  bool _cancelRequested = false;
  PortScanCategory? _filter;

  Future<void> _start(Device device) async {
    final DevicePortScanner scanner = DevicePortScanner();
    _scanner = scanner;
    setState(() {
      _scanning = true;
      _cancelRequested = false;
      _error = null;
      _report = null;
      _progress = const DevicePortScanProgress(message: '正在准备扫描…');
      _filter = null;
    });
    try {
      final DevicePortScanReport report = await scanner.scan(
        device.primaryAddress,
        onProgress: (DevicePortScanProgress progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _scanning = false;
        _cancelRequested = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanning = false;
        _error = '扫描失败：$error';
      });
    } finally {
      _scanner = null;
    }
  }

  void _cancel() {
    _scanner?.cancel();
    setState(() => _cancelRequested = true);
  }

  Future<void> _addService(
    Device device,
    DevicePortResult result,
    LanDeckRepository repository,
  ) async {
    final ScanCandidate candidate = ScanCandidate(
      id: '${device.primaryAddress}:${result.port}',
      host: device.primaryAddress,
      port: result.port,
      url:
          result.url ??
          buildScanUrl(
            device.primaryAddress,
            result.port,
            https: result.scheme == 'https',
          ),
      sources: const <ScanSource>{ScanSource.port},
      confidence: result.isWeb
          ? ScanConfidence.confirmed
          : ScanConfidence.candidate,
      title: result.title,
      statusCode: result.statusCode,
      server: result.server,
      note: result.note,
    );
    final Service? saved = await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) =>
            ServiceEditorPage(candidate: candidate, initialDeviceId: device.id),
      ),
    );
    if (saved != null && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已添加服务「${saved.name}」')));
    }
  }

  bool _isAdded(LanDeckRepository repository, DevicePortResult result) {
    final String? url = result.url;
    if (url == null) {
      return false;
    }
    final String key = canonicalHttpUrl(url);
    return repository.services.any(
      (Service service) => canonicalHttpUrl(service.url) == key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(widget.deviceId);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('扫描服务')),
        body: const Center(child: Text('设备已不存在')),
      );
    }
    final List<DevicePortResult> results =
        _report?.results ?? const <DevicePortResult>[];
    final List<DevicePortResult> filtered = _filter == null
        ? results
        : results
              .where((DevicePortResult result) => result.category == _filter)
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('扫描服务')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kListPageMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                32,
              ),
              children: <Widget>[
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        ServiceIconBadge(icon: iconForDevice(device), size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                device.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${device.primaryAddress} · 仅扫描该设备',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _scanning ? '正在扫描端口' : '常见 Web 端口扫描',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (_scanning)
                              TextButton.icon(
                                onPressed: _cancelRequested ? null : _cancel,
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: Text(_cancelRequested ? '正在取消…' : '取消'),
                              )
                            else
                              FilledButton.icon(
                                key: const ValueKey<String>(
                                  'device-scan-start',
                                ),
                                onPressed: () => _start(device),
                                icon: const Icon(Icons.radar_rounded),
                                label: Text(_report == null ? '开始扫描' : '重新扫描'),
                              ),
                          ],
                        ),
                        if (_scanning) ...<Widget>[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _progress?.ratio == 0
                                ? null
                                : _progress?.ratio,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _progress?.message ?? '正在准备…',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ] else ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            '只连接 ${device.primaryAddress} 的常见 Web 端口，'
                            '并验证 HTTP / HTTPS，不会扫描其他设备。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      title: Text(_error!),
                    ),
                  ),
                ],
                if (_report != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Text(
                        '扫描结果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${results.length}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      if (_report!.confirmedCount > 0)
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: Text('已确认 ${_report!.confirmedCount}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilterChip(
                        label: const Text('全部'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final PortScanCategory category
                          in PortScanCategory.values)
                        FilterChip(
                          label: Text(category.label),
                          selected: _filter == category,
                          onSelected: (_) => setState(() => _filter = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Card.outlined(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: <Widget>[
                            const Icon(Icons.search_off_rounded, size: 34),
                            const SizedBox(height: 8),
                            Text(
                              '没有符合条件的结果',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '可以切换筛选条件或重新扫描。',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final DevicePortResult result in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PortResultCard(
                          result: result,
                          added: _isAdded(repository, result),
                          onAdd: () => _addService(device, result, repository),
                        ),
                      ),
                ],
                if (_report?.cancelled == true) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text('扫描已取消，未保留结果。'),
                ],
                const SizedBox(height: 12),
                Text(
                  'HTTP 401 / 403 / 404 同样可能表示真实 Web 服务；'
                  '端口开放但未获得 HTTP 响应时标记为候选。确认后才会写入服务。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortResultCard extends StatelessWidget {
  const _PortResultCard({
    required this.result,
    required this.added,
    required this.onAdd,
  });

  final DevicePortResult result;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              result.isWeb
                  ? (result.scheme == 'https'
                        ? Icons.lock_outline_rounded
                        : Icons.language_rounded)
                  : Icons.lan_outlined,
              color: scheme.primary,
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
                          result.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Chip(
                        label: Text(result.category.label),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ':${result.port} · ${result.url ?? '无 URL'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (result.detailLabel.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      result.detailLabel,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            added
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.check_rounded),
                  )
                : FilledButton.tonal(
                    key: ValueKey<String>('device-scan-add-${result.port}'),
                    onPressed: onAdd,
                    child: const Text('添加'),
                  ),
          ],
        ),
      ),
    );
  }
}
