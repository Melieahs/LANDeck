import 'package:flutter/material.dart';

import '../models/device.dart';
import '../models/device_category.dart';
import '../models/service.dart';

IconData iconForDeviceType(DeviceType type) => switch (type) {
  DeviceType.nas => Icons.storage_rounded,
  DeviceType.router => Icons.router_rounded,
  DeviceType.computer => Icons.desktop_windows_rounded,
  DeviceType.docker => Icons.view_in_ar_rounded,
  DeviceType.phone => Icons.smartphone_rounded,
  DeviceType.media => Icons.movie_rounded,
  DeviceType.other => Icons.more_horiz_rounded,
};

const Map<String, IconData> deviceIconChoices = <String, IconData>{
  'storage': Icons.storage_rounded,
  'router': Icons.router_rounded,
  'computer': Icons.desktop_windows_rounded,
  'server': Icons.dns_rounded,
  'phone': Icons.smartphone_rounded,
  'media': Icons.movie_rounded,
  'home': Icons.home_rounded,
  'devices': Icons.devices_other_rounded,
};

IconData iconForDevice(Device device) {
  final String? icon = device.icon;
  if (icon != null && deviceIconChoices.containsKey(icon)) {
    return deviceIconChoices[icon]!;
  }
  return iconForDeviceType(device.deviceType);
}

IconData iconForCategory(DeviceCategory category) => switch (category) {
  DeviceCategory.all => Icons.grid_view_rounded,
  DeviceCategory.nas => Icons.storage_rounded,
  DeviceCategory.router => Icons.router_rounded,
  DeviceCategory.computer => Icons.desktop_windows_rounded,
  DeviceCategory.docker => Icons.view_in_ar_rounded,
  DeviceCategory.phone => Icons.smartphone_rounded,
  DeviceCategory.media => Icons.movie_rounded,
  DeviceCategory.other => Icons.more_horiz_rounded,
};

IconData iconForGlyph(ServiceGlyph? glyph) => switch (glyph) {
  ServiceGlyph.nas => Icons.storage_rounded,
  ServiceGlyph.router => Icons.router_rounded,
  ServiceGlyph.docker => Icons.view_in_ar_rounded,
  ServiceGlyph.media => Icons.play_circle_fill_rounded,
  ServiceGlyph.download => Icons.download_rounded,
  ServiceGlyph.home => Icons.home_rounded,
  ServiceGlyph.generic || null => Icons.language_rounded,
};

IconData iconForService(Service service) {
  if (service.icon != null) {
    return iconForGlyph(service.icon);
  }
  final DeviceCategory? category = service.category;
  if (category != null) {
    return switch (category) {
      DeviceCategory.all => Icons.language_rounded,
      DeviceCategory.nas => Icons.storage_rounded,
      DeviceCategory.router => Icons.router_rounded,
      DeviceCategory.computer => Icons.desktop_windows_rounded,
      DeviceCategory.docker => Icons.view_in_ar_rounded,
      DeviceCategory.phone => Icons.smartphone_rounded,
      DeviceCategory.media => Icons.play_circle_fill_rounded,
      DeviceCategory.other => Icons.more_horiz_rounded,
    };
  }
  return Icons.language_rounded;
}

/// Material 3 tonal icon tile shared by every service presentation.
class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({
    super.key,
    required this.icon,
    this.size = 46,
    this.emphasized = false,
  });

  final IconData icon;
  final double size;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.47,
        color: emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
    );
  }
}
