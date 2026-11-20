import 'package:material_ui/material_ui.dart';

import '../../../models/device.dart';
import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_list_tile.dart';
import '../../../widgets/sort_menu.dart';

enum _ServiceSort { name, status, device, category }

class AllServicesSection extends StatefulWidget {
  const AllServicesSection({
    super.key,
    required this.services,
    required this.query,
    required this.deviceNameFor,
    required this.deviceTypeFor,
    required this.onOpenService,
    required this.onClearSearch,
    required this.onAddService,
    required this.onScan,
  });

  final List<Service> services;
  final String query;
  final String Function(Service service) deviceNameFor;
  final DeviceType? Function(Service service) deviceTypeFor;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onClearSearch;
  final VoidCallback onAddService;
  final VoidCallback onScan;

  @override
  State<AllServicesSection> createState() => _AllServicesSectionState();
}

class _AllServicesSectionState extends State<AllServicesSection> {
  _ServiceSort _sort = _ServiceSort.name;
  DeviceType? _deviceType;
  bool _onlyUnassigned = false;

  bool get _isSearching => widget.query.trim().isNotEmpty;

  List<Service> get _visible {
    final List<Service> list = widget.services.where((Service service) {
      final DeviceType? type = widget.deviceTypeFor(service);
      if (_onlyUnassigned) return type == null;
      if (_deviceType != null) return type == _deviceType;
      return true;
    }).toList();

    switch (_sort) {
      case _ServiceSort.name:
        list.sort(
          (Service a, Service b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _ServiceSort.status:
        list.sort((Service a, Service b) {
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _ServiceSort.device:
        list.sort((Service a, Service b) {
          final int byDevice = widget
              .deviceNameFor(a)
              .toLowerCase()
              .compareTo(widget.deviceNameFor(b).toLowerCase());
          return byDevice != 0
              ? byDevice
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _ServiceSort.category:
        list.sort((Service a, Service b) {
          final int byCategory = a.categoryLabel.compareTo(b.categoryLabel);
          return byCategory != 0
              ? byCategory
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  int _countFor(DeviceType type) => widget.services
      .where((Service service) => widget.deviceTypeFor(service) == type)
      .length;

  int get _unassignedCount => widget.services
      .where((Service service) => widget.deviceTypeFor(service) == null)
      .length;

  bool get _hasFilter => _deviceType != null || _onlyUnassigned;

  void _clearFilter() {
    setState(() {
      _deviceType = null;
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
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SortMenu<_ServiceSort>(
                current: _sort,
                onSelected: (_ServiceSort value) =>
                    setState(() => _sort = value),
                choices: const <SortChoice<_ServiceSort>>[
                  SortChoice<_ServiceSort>(
                    value: _ServiceSort.name,
                    label: '按名称',
                  ),
                  SortChoice<_ServiceSort>(
                    value: _ServiceSort.status,
                    label: '按在线状态',
                  ),
                  SortChoice<_ServiceSort>(
                    value: _ServiceSort.device,
                    label: '按设备',
                  ),
                  SortChoice<_ServiceSort>(
                    value: _ServiceSort.category,
                    label: '按服务分类',
                  ),
                ],
              ),
              IconButton(
                key: const ValueKey<String>('all-services-add'),
                onPressed: widget.onAddService,
                tooltip: '添加服务',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
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
                for (final DeviceType type in DeviceType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey<String>('service-filter-${type.name}'),
                      selected: _deviceType == type && !_onlyUnassigned,
                      label: Text('${type.label} ${_countFor(type)}'),
                      onSelected: (_) => setState(() {
                        _onlyUnassigned = false;
                        _deviceType = _deviceType == type ? null : type;
                      }),
                    ),
                  ),
                ChoiceChip(
                  key: const ValueKey<String>('service-filter-unassigned'),
                  selected: _onlyUnassigned,
                  label: Text('未分配 $_unassignedCount'),
                  onSelected: (_) => setState(() {
                    _deviceType = null;
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
