import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/status_dot.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.serviceCount,
    required this.onlineCount,
    required this.onOpenSettings,
  });

  final int serviceCount;
  final int onlineCount;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '我的网络',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            StatusDot(isOnline: onlineCount > 0, size: 6),
            const SizedBox(width: 8),
            Text(
              '$serviceCount 个本地服务',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 7),
              child: Text(
                '·',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
            Text(
              '$onlineCount 在线',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: onlineCount > 0 ? AppColors.online : AppColors.textMuted,
              ),
            ),
            const Spacer(),
            _SettingsPill(onTap: onOpenSettings),
          ],
        ),
      ],
    );
  }
}

class _SettingsPill extends StatelessWidget {
  const _SettingsPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.settings_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
