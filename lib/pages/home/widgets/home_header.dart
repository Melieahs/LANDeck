import 'package:material_ui/material_ui.dart';

/// Home overview: a restrained Material 3 summary instead of a dashboard.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.serviceCount,
    required this.deviceCount,
    required this.onlineCount,
  });

  final int serviceCount;
  final int deviceCount;
  final int onlineCount;

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
        const SizedBox(height: 4),
        Text(
          '本地优先，不经过云端',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                    value: '$serviceCount',
                    label: '服务',
                    icon: Icons.dns_outlined,
                  ),
                ),
                _Divider(color: scheme.outlineVariant),
                Expanded(
                  child: _Stat(
                    value: '$deviceCount',
                    label: '设备',
                    icon: Icons.devices_other_outlined,
                  ),
                ),
                _Divider(color: scheme.outlineVariant),
                Expanded(
                  child: _Stat(
                    value: '$onlineCount',
                    label: '在线',
                    icon: Icons.wifi_tethering_rounded,
                    highlight: onlineCount > 0,
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
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          icon,
          size: 18,
          color: highlight ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: text.titleLarge?.copyWith(
                color: highlight ? scheme.primary : scheme.onSurface,
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
