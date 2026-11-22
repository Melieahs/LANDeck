import 'package:material_ui/material_ui.dart';

import '../core/app_scope.dart';
import '../core/utils/feedback.dart';
import '../models/service.dart';
import '../pages/services/service_editor_page.dart';
import 'service_icon.dart';

/// Material 3 list row used by the home service list, category pages and
/// device detail. Tapping the row opens the real WebView; the overflow menu
/// keeps edit/delete close at hand.
class ServiceListTile extends StatelessWidget {
  const ServiceListTile({
    super.key,
    required this.service,
    required this.deviceName,
    required this.onTap,
  });

  final Service service;
  final String deviceName;
  final VoidCallback onTap;

  Future<void> _editService(BuildContext context) async {
    await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => ServiceEditorPage(service: service),
      ),
    );
  }

  Future<void> _deleteService(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('删除服务？'),
        content: Text('将删除「${service.name}」。此操作不会影响关联设备。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await AppScope.of(context).deleteService(service.id);
    if (context.mounted) {
      showAppSnackBar(context, '已删除 ${service.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String address = service.address.isEmpty ? '未设置地址' : service.address;

    return ListTile(
      onTap: onTap,
      isThreeLine: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
      leading: ServiceIconBadge(
        icon: iconForService(service),
        emphasized: service.isFavorite,
      ),
      title: Text(
        service.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Text(
            '$deviceName · ${service.categoryLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 1),
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PopupMenuButton<String>(
            key: ValueKey<String>('service-menu-${service.id}'),
            tooltip: '服务操作',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (String value) {
              if (value == 'edit') {
                _editService(context);
              } else if (value == 'delete') {
                _deleteService(context);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('编辑服务'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('删除服务'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }
}
