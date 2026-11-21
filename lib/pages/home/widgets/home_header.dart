import 'package:material_ui/material_ui.dart';

/// Home overview: a restrained Material 3 summary instead of a dashboard.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.serviceCount,
    required this.deviceCount,
    required this.onOpenServices,
    required this.onOpenDevices,
  });

  final int serviceCount;
  final int deviceCount;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '我的网络',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          color: scheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    key: const ValueKey<String>('home-stat-services'),
                    value: '$serviceCount',
                    label: '服务',
                    icon: Icons.dns_outlined,
                    onTap: onOpenServices,
                  ),
                ),
                _Divider(color: scheme.outlineVariant),
                Expanded(
                  child: _Stat(
                    key: const ValueKey<String>('home-stat-devices'),
                    value: '$deviceCount',
                    label: '设备',
                    icon: Icons.devices_other_outlined,
                    onTap: onOpenDevices,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: text.titleLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: color);
  }
}
