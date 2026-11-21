import 'package:material_ui/material_ui.dart';

import '../../../models/device.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';

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

class _DevicesSectionState extends State<DevicesSection> {
  List<Device> get _visible {
    final List<Device> list = List<Device>.of(widget.devices);
    list.sort(
      (Device a, Device b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return list;
  }

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
              : '${widget.devices.length} 台',
          action: TextButton(
            onPressed: widget.devices.isEmpty
                ? widget.onAddDevice
                : widget.onManage,
            child: Text(widget.devices.isEmpty ? '添加设备' : '管理'),
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
                      maxLines: 2,
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
