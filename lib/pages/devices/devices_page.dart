import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
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
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '设备管理',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${devices.length} 台',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey<String>('add-device-button'),
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accentSoft,
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (devices.isEmpty)
                  _EmptyDevices(onAdd: () => _openEditor(context))
                else
                  ...devices.map(
                    (Device device) => Padding(
                      key: ValueKey<String>('device-${device.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeviceCard(
                        device: device,
                        serviceCount: repository.serviceCountForDevice(device),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                DeviceDetailPage(deviceId: device.id),
                          ),
                        ),
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.serviceCount,
    required this.onTap,
  });

  final Device device;
  final int serviceCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          child: Row(
            children: <Widget>[
              ServiceIconBadge(
                icon: iconForDeviceType(device.deviceType),
                emphasized: device.deviceType == DeviceType.nas,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.deviceType.label} · ${device.addressLabel} · $serviceCount 个服务',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.textMuted,
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 30),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.devices_other_rounded,
            size: 34,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            '还没有添加设备',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '创建设备后，可以把服务归类到 NAS、路由器或电脑。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('添加设备'),
          ),
        ],
      ),
    );
  }
}
