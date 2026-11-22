import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/service_icon.dart';
import 'device_detail_page.dart';
import 'device_editor_page.dart';
import '../../widgets/empty_state.dart';

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
            constraints: const BoxConstraints(maxWidth: kListPageMaxWidth),
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
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            12,
                            8,
                          ),
                          leading: ServiceIconBadge(
                            icon: iconForDevice(device),
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
    return EmptyState(
      icon: Icons.devices_other_rounded,
      title: '还没有添加设备',
      message: '添加设备后，可以把服务归类到 NAS、路由器或电脑，并只需输入端口即可创建服务。',
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加设备'),
      ),
    );
  }
}
