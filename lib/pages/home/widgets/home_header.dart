import 'package:material_ui/material_ui.dart';

/// Home overview: a compact summary line under the search field.
///
/// Counts stay tappable so the service and device pages remain one gesture
/// away, but they no longer occupy a full card above the favourites.
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
    return Row(
      children: <Widget>[
        _Count(
          key: const ValueKey<String>('home-stat-services'),
          icon: Icons.dns_outlined,
          value: serviceCount,
          unit: '个服务',
          onTap: onOpenServices,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '·',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
        _Count(
          key: const ValueKey<String>('home-stat-devices'),
          icon: Icons.devices_other_outlined,
          value: deviceCount,
          unit: '台设备',
          onTap: onOpenDevices,
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    super.key,
    required this.icon,
    required this.value,
    required this.unit,
    required this.onTap,
  });

  final IconData icon;
  final int value;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: text.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
