import 'package:material_ui/material_ui.dart';

import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_list_tile.dart';

class AllServicesSection extends StatefulWidget {
  const AllServicesSection({
    super.key,
    required this.services,
    required this.query,
    required this.deviceNameFor,
    required this.onOpenService,
    required this.onClearSearch,
    required this.onAddService,
    required this.onScan,
  });

  final List<Service> services;
  final String query;
  final String Function(Service service) deviceNameFor;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onClearSearch;
  final VoidCallback onAddService;
  final VoidCallback onScan;

  @override
  State<AllServicesSection> createState() => _AllServicesSectionState();
}

class _AllServicesSectionState extends State<AllServicesSection> {
  bool get _isSearching => widget.query.trim().isNotEmpty;

  List<Service> get _visible {
    final List<Service> list = List<Service>.of(widget.services);
    list.sort(
      (Service a, Service b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final List<Service> visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '全部服务',
          trailing: _isSearching
              ? '${visible.length} 个结果'
              : '共 ${widget.services.length} 个',
          action: IconButton(
            key: const ValueKey<String>('all-services-add'),
            onPressed: widget.onAddService,
            tooltip: '添加服务',
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        if (widget.services.isEmpty)
          _isSearching
              ? _EmptySearchState(onClearSearch: widget.onClearSearch)
              : _EmptyServicesState(
                  onAddService: widget.onAddService,
                  onScan: widget.onScan,
                )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < visible.length;
                  index++
                ) ...<Widget>[
                  ServiceListTile(
                    key: ValueKey<String>('service-${visible[index].id}'),
                    service: visible[index],
                    deviceName: widget.deviceNameFor(visible[index]),
                    onTap: () => widget.onOpenService(visible[index]),
                  ),
                  if (index != visible.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({required this.onAddService, required this.onScan});

  final VoidCallback onAddService;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: <Widget>[
            Icon(Icons.dns_outlined, size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('还没有添加服务', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              '扫描当前局域网，或手动填写一个 Web 服务地址。',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onScan,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('扫描局域网'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddService,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('手动添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text('没有找到匹配的服务', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '试试服务名称、设备或 IP 地址',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onClearSearch, child: const Text('清除搜索')),
          ],
        ),
      ),
    );
  }
}
