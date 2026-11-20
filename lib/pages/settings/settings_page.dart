import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../devices/devices_page.dart';
import '../../repositories/service_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onOpenDiscover});

  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '本地优先 · 无账号 · 无云端',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      _SettingsRow(
                        icon: Icons.devices_other_rounded,
                        title: '设备管理',
                        value: '${repository.devices.length} 台',
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const DevicesPage(),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 52),
                      _SettingsRow(
                        icon: Icons.wifi_tethering_rounded,
                        title: '局域网扫描',
                        value: '在发现中',
                        onTap: onOpenDiscover,
                      ),
                      const Divider(height: 1, indent: 52),
                      _SettingsRow(
                        icon: Icons.dark_mode_rounded,
                        title: '外观',
                        value: '深色',
                        onTap: () => showAppSnackBar(
                          context,
                          '当前版本固定为深色主题',
                        ),
                      ),
                      const Divider(height: 1, indent: 52),
                      _SettingsRow(
                        icon: Icons.storage_rounded,
                        title: '数据存储',
                        value: '本机数据库',
                        onTap: () => showAppSnackBar(
                          context,
                          '${repository.services.length} 个服务、'
                          '${repository.devices.length} 台设备保存在本机 Sembast 数据库',
                        ),
                      ),
                      const Divider(height: 1, indent: 52),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        title: '关于 LANDeck',
                        value: 'v0.4.0',
                        onTap: () => showAppSnackBar(
                          context,
                          'LANDeck v0.4.0 · HTTP 身份验证',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 7),
                          Text(
                            '隐私',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 7),
                      Text(
                        '服务、设备与扫描结果只在本机处理。'
                        '扫描仅访问当前 Wi-Fi 网段，不上传任何数据，也不请求定位权限。',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.65,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'LANDeck · Local-first',
                    style: TextStyle(
                      fontSize: 11,
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
