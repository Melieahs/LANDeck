import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/service_icon.dart';
import 'device_detail_page.dart';
import 'device_editor_page.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  Future<void> _openEditor(BuildContext context) async {
    await Navigator.of(context).push<Device>(
      MaterialPageRoute<Device>(
        builder: (BuildContext context) => const DeviceEditorPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final List<Device> devices = repository.devices;
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('add-device-button'),
            tooltip: '添加设备',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加设备'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: devices.isEmpty
                ? _EmptyDevices(onAdd: () => _openEditor(context))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      12,
                      AppSpacing.page,
                      100,
                    ),
                    itemCount: devices.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            '${devices.length} 台设备 · 点击查看关联服务',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final Device device = devices[index - 1];
                      return Card.outlined(
                        key: ValueKey<String>('device-${device.id}'),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                          leading: ServiceIconBadge(
                            icon: iconForDeviceType(device.deviceType),
                            emphasized: device.deviceType == DeviceType.nas,
                          ),
                          title: Text(device.name),
                          subtitle: Text(
                            '${device.deviceType.label} · ${device.addressLabel}\n'
                            '${repository.serviceCountForDevice(device)} 个服务',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  DeviceDetailPage(deviceId: device.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.devices_other_rounded,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有添加设备',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '添加设备后，可以把服务归类到 NAS、路由器或电脑，并只需输入端口即可创建服务。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加设备'),
            ),
          ],
        ),
      ),
    );
  }
}
