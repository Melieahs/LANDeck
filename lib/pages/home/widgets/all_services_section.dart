import 'package:material_ui/material_ui.dart';

import '../../../models/device.dart';
import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/service_list_tile.dart';
class AllServicesSection extends StatefulWidget {
  const AllServicesSection({
    super.key,
    required this.services,
    required this.query,
    required this.deviceNameFor,
    required this.devices,
    required this.onOpenService,
    required this.onClearSearch,
    required this.onAddService,
    required this.onScan,
  });

  final List<Service> services;
  final String query;
  final String Function(Service service) deviceNameFor;
  final List<Device> devices;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onClearSearch;
  final VoidCallback onAddService;
  final VoidCallback onScan;

  @override
  State<AllServicesSection> createState() => _AllServicesSectionState();
}

class _AllServicesSectionState extends State<AllServicesSection> {
  String? _deviceId;
  bool _onlyUnassigned = false;

  bool get _isSearching => widget.query.trim().isNotEmpty;

  List<Service> get _visible {
    final List<Service> list = widget.services.where((Service service) {
      if (_onlyUnassigned) return service.deviceId == null;
      if (_deviceId != null) return service.deviceId == _deviceId;
      return true;
    }).toList();

    list.sort(
      (Service a, Service b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

  int _countForDevice(String deviceId) => widget.services
      .where((Service service) => service.deviceId == deviceId)
      .length;

  int get _unassignedCount => widget.services
      .where((Service service) => service.deviceId == null)
      .length;

  bool get _hasFilter => _deviceId != null || _onlyUnassigned;

  void _clearFilter() {
    setState(() {
      _deviceId = null;
      _onlyUnassigned = false;
    });
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
              : _hasFilter
              ? '${visible.length} / ${widget.services.length} 个'
              : '共 ${widget.services.length} 个',
          action: IconButton(
            key: const ValueKey<String>('all-services-add'),
            onPressed: widget.onAddService,
            tooltip: '添加服务',
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        if (widget.services.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: const ValueKey<String>('service-filter-all'),
                    selected: !_hasFilter,
                    avatar: const Icon(Icons.devices_other_rounded, size: 18),
                    label: Text('全部设备 ${widget.services.length}'),
                    onSelected: (_) => _clearFilter(),
                  ),
                ),
                for (final Device device in widget.devices)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>(
                        'service-filter-device-${device.id}',
                      ),
                      selected: _deviceId == device.id && !_onlyUnassigned,
                      avatar: Icon(iconForDevice(device), size: 18),
                      label: Text(
                        '${device.name} ${_countForDevice(device.id)}',
                      ),
                      onSelected: (_) => setState(() {
                        _onlyUnassigned = false;
                        _deviceId = _deviceId == device.id ? null : device.id;
                      }),
                    ),
                  ),
                ChoiceChip(
                  key: const ValueKey<String>('service-filter-unassigned'),
                  selected: _onlyUnassigned,
                  label: Text('未分配 $_unassignedCount'),
                  onSelected: (_) => setState(() {
                    _deviceId = null;
                    _onlyUnassigned = !_onlyUnassigned;
                  }),
                ),
              ],
            ),
          ),
        if (widget.services.isEmpty)
          _isSearching
              ? _EmptySearchState(onClearSearch: widget.onClearSearch)
              : _EmptyServicesState(
                  onAddService: widget.onAddService,
                  onScan: widget.onScan,
                )
        else if (visible.isEmpty)
          _EmptyFilteredState(onClear: _clearFilter)
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
                    const Divider(height: 1, indent: 72),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  const _EmptyFilteredState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: ListTile(
        leading: const Icon(Icons.filter_alt_off_outlined),
        title: const Text('该设备分类下暂无服务'),
        subtitle: const Text('切换一个设备分类，或查看全部服务。'),
        trailing: TextButton(onPressed: onClear, child: const Text('查看全部')),
      ),
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
