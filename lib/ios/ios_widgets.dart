import 'package:cupertino_ui/cupertino_ui.dart';

import '../models/device.dart';
import '../models/service.dart';

IconData iosDeviceIcon(DeviceType type) {
  return switch (type) {
    DeviceType.nas => CupertinoIcons.archivebox_fill,
    DeviceType.router => CupertinoIcons.wifi,
    DeviceType.computer => CupertinoIcons.desktopcomputer,
    DeviceType.docker => CupertinoIcons.rectangle_stack,
    DeviceType.phone => CupertinoIcons.device_phone_portrait,
    DeviceType.media => CupertinoIcons.play_rectangle,
    DeviceType.other => CupertinoIcons.square_grid_2x2,
  };
}

IconData iosServiceIcon(Service service) {
  return switch (service.icon) {
    ServiceGlyph.nas => CupertinoIcons.archivebox_fill,
    ServiceGlyph.router => CupertinoIcons.wifi,
    ServiceGlyph.docker => CupertinoIcons.rectangle_stack,
    ServiceGlyph.media => CupertinoIcons.play_rectangle,
    ServiceGlyph.download => CupertinoIcons.tray_arrow_down,
    ServiceGlyph.home => CupertinoIcons.house,
    ServiceGlyph.generic => CupertinoIcons.globe,
    null => CupertinoIcons.globe,
  };
}

class IosStatusText extends StatelessWidget {
  const IosStatusText({super.key, required this.isOnline, this.unknown = false});

  final bool isOnline;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final Color color = unknown
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : isOnline
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemGrey.resolveFrom(context);
    final String label = unknown ? '未知' : (isOnline ? '在线' : '离线');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

class IosEmptyTile extends StatelessWidget {
  const IosEmptyTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: Icon(
        CupertinoIcons.sparkles,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
