import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../service/service_viewer_page.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/service_list_tile.dart';
import '../services/service_editor_page.dart';
import 'device_editor_page.dart';
import 'device_service_scan_page.dart';

class DeviceDetailPage extends StatelessWidget {
  const DeviceDetailPage({super.key, required this.deviceId});

  final String deviceId;

  Future<void> _edit(BuildContext context, Device device) async {
    await Navigator.of(context).push<Device>(
      MaterialPageRoute<Device>(
        builder: (BuildContext context) => DeviceEditorPage(device: device),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    LanDeckRepository repository,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('删除设备？'),
        content: const Text('关联服务不会被删除，现有 URL 会保留并移动到「未分配设备」。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await repository.deleteDevice(deviceId);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _scanServices(BuildContext context, Device device) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DeviceServiceScanPage(deviceId: device.id),
      ),
    );
  }

  Future<void> _addService(BuildContext context, Device device) async {
    await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) =>
            ServiceEditorPage(initialDeviceId: device.id, quickMode: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(deviceId);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('设备已不存在'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }
    final List<Service> services = repository.servicesForDevice(device);
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('device-scan-services'),
            tooltip: '扫描服务',
            onPressed: () => _scanServices(context, device),
            icon: const Icon(Icons.radar_rounded),
          ),
          IconButton(
            tooltip: '编辑设备',
            onPressed: () => _edit(context, device),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '删除设备',
            onPressed: () => _delete(context, repository),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('device-add-service'),
        onPressed: () => _addService(context, device),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加服务'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSettingsPageMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                100,
              ),
              children: <Widget>[
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        ServiceIconBadge(
                          icon: iconForDevice(device),
                          size: 56,
                          emphasized: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                device.deviceType.label,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                device.primaryAddress,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (device.notes != null) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  device.notes!,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _scanServices(context, device),
                    icon: const Icon(Icons.radar_rounded),
                    label: const Text('扫描该设备的服务端口'),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Text(
                      '关联服务',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${services.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.link_off_rounded),
                      title: const Text('这台设备还没有关联服务'),
                      subtitle: const Text('使用右下角按钮，只需输入端口即可添加。'),
                    ),
                  )
                else
                  Card.outlined(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < services.length; i++) ...<Widget>[
                          ServiceListTile(
                            key: ValueKey<String>(
                              'device-service-${services[i].id}',
                            ),
                            service: services[i],
                            deviceName: device.name,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    ServiceViewerPage(serviceId: services[i].id),
                              ),
                            ),
                          ),
                          if (i != services.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  '设备地址修改后，关联服务的 URL 会自动更新。',
                  textAlign: TextAlign.center,
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
