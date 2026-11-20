import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../pages/webview/web_view_page.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/service_list_tile.dart';
import '../services/service_editor_page.dart';
import 'device_editor_page.dart';

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

  Future<void> _delete(BuildContext context, LanDeckRepository repository) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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
              backgroundColor: const Color(0xFF6B2733),
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

  Future<void> _addService(BuildContext context, Device device) async {
    await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => ServiceEditorPage(
          initialDeviceId: device.id,
          quickMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(deviceId);
    if (device == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  '设备已不存在',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final List<Service> services = repository.servicesForDevice(device);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                4,
                AppSpacing.page,
                28,
              ),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _edit(context, device),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _delete(context, repository),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: const Color(0xFFFF8A96),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      ServiceIconBadge(
                        icon: iconForDeviceType(device.deviceType),
                        size: 56,
                        emphasized: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              device.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${device.deviceType.label} · ${device.addressLabel}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _InfoLine(label: '地址', value: device.primaryAddress),
                      if (device.notes != null) ...<Widget>[
                        const SizedBox(height: 8),
                        _InfoLine(label: '备注', value: device.notes!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Text(
                      '关联服务',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${services.length}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const ValueKey<String>('device-add-service'),
                      onPressed: () => _addService(context, device),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('添加服务'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                if (services.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      children: <Widget>[
                        Icon(
                          Icons.link_off_rounded,
                          size: 26,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '这台设备还没有关联服务',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...services.map(
                    (Service service) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ServiceListTile(
                        key: ValueKey<String>('device-service-${service.id}'),
                        service: service,
                        deviceName: device.name,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                WebViewPage(serviceId: service.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '设备地址修改后，关联服务的 URL 会自动更新。',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
