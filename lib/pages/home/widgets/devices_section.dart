import 'package:material_ui/material_ui.dart';

import '../../../models/device.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/sort_menu.dart';

/// Device module with its category filter built in.
///
/// Categories describe devices, not services. Tapping a category filters the
/// device cards in place instead of opening a separate service category page.
class DevicesSection extends StatefulWidget {
  const DevicesSection({
    super.key,
    required this.devices,
    required this.serviceCountForDevice,
    required this.onOpenDevice,
    required this.onManage,
    required this.onAddDevice,
  });

  final List<Device> devices;
  final int Function(Device device) serviceCountForDevice;
  final ValueChanged<Device> onOpenDevice;
  final VoidCallback onManage;
  final VoidCallback onAddDevice;

  @override
  State<DevicesSection> createState() => _DevicesSectionState();
}

enum _DeviceSort { name, type, services, address }

class _DevicesSectionState extends State<DevicesSection> {
  DeviceType? _selected;
  _DeviceSort _sort = _DeviceSort.name;

  List<Device> get _visible {
    final List<Device> list = _selected == null
        ? List<Device>.of(widget.devices)
        : widget.devices
              .where((Device device) => device.deviceType == _selected)
              .toList();
    switch (_sort) {
      case _DeviceSort.name:
        list.sort(
          (Device a, Device b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _DeviceSort.type:
        list.sort((Device a, Device b) {
          final int byType = a.deviceType.index.compareTo(b.deviceType.index);
          return byType != 0
              ? byType
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _DeviceSort.services:
        list.sort((Device a, Device b) {
          final int byCount = widget
              .serviceCountForDevice(b)
              .compareTo(widget.serviceCountForDevice(a));
          return byCount != 0
              ? byCount
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _DeviceSort.address:
        list.sort(
          (Device a, Device b) => a.primaryAddress.toLowerCase().compareTo(
            b.primaryAddress.toLowerCase(),
          ),
        );
    }
    return list;
  }

  int _countFor(DeviceType type) =>
      widget.devices.where((Device device) => device.deviceType == type).length;

  @override
  Widget build(BuildContext context) {
    final List<Device> visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '设备',
          trailing: widget.devices.isEmpty
              ? null
              : _selected == null
              ? '${widget.devices.length} 台'
              : '${visible.length} / ${widget.devices.length} 台',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.devices.isNotEmpty)
                SortMenu<_DeviceSort>(
                  current: _sort,
                  onSelected: (_DeviceSort value) =>
                      setState(() => _sort = value),
                  choices: const <SortChoice<_DeviceSort>>[
                    SortChoice<_DeviceSort>(
                      value: _DeviceSort.name,
                      label: '按名称',
                    ),
                    SortChoice<_DeviceSort>(
                      value: _DeviceSort.type,
                      label: '按设备类型',
                    ),
                    SortChoice<_DeviceSort>(
                      value: _DeviceSort.services,
                      label: '按服务数量',
                    ),
                    SortChoice<_DeviceSort>(
                      value: _DeviceSort.address,
                      label: '按地址',
                    ),
                  ],
                ),
              TextButton(
                onPressed: widget.devices.isEmpty
                    ? widget.onAddDevice
                    : widget.onManage,
                child: Text(widget.devices.isEmpty ? '添加设备' : '管理'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const ValueKey<String>('device-filter-all'),
                  selected: _selected == null,
                  avatar: const Icon(Icons.grid_view_rounded, size: 18),
                  label: Text('全部设备 ${widget.devices.length}'),
                  onSelected: (_) => setState(() => _selected = null),
                ),
              ),
              for (final DeviceType type in DeviceType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey<String>('device-filter-${type.name}'),
                    selected: _selected == type,
                    avatar: Icon(iconForDeviceType(type), size: 18),
                    label: Text('${type.label} ${_countFor(type)}'),
                    onSelected: (_) => setState(
                      () => _selected = _selected == type ? null : type,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.devices.isEmpty)
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.devices_other_outlined),
              title: const Text('还没有添加设备'),
              subtitle: const Text('添加设备后，只需输入端口即可创建服务。'),
              trailing: FilledButton.tonal(
                onPressed: widget.onAddDevice,
                child: const Text('添加'),
              ),
            ),
          )
        else if (visible.isEmpty)
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.filter_alt_off_outlined),
              title: const Text('该分类下暂无设备'),
              subtitle: const Text('可以切换分类，或添加一台新的设备。'),
              trailing: TextButton(
                onPressed: () => setState(() => _selected = null),
                child: const Text('查看全部'),
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final Device device = visible[index];
                return SizedBox(
                  width: 210,
                  child: _DeviceCard(
                    key: ValueKey<String>('home-device-${device.id}'),
                    device: device,
                    serviceCount: widget.serviceCountForDevice(device),
                    onTap: () => widget.onOpenDevice(device),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    super.key,
    required this.device,
    required this.serviceCount,
    required this.onTap,
  });

  final Device device;
  final int serviceCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ServiceIconBadge(
                icon: iconForDevice(device),
                size: 42,
                emphasized: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.deviceType.label} · $serviceCount 个服务',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.addressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
