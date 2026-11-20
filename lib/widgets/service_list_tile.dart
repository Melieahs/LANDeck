import 'package:material_ui/material_ui.dart';

import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/feedback.dart';
import '../pages/services/service_editor_page.dart';
import '../models/service.dart';
import 'service_icon.dart';
import 'status_dot.dart';

/// A service row used by both "全部服务" and category filter pages.
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
    final TextStyle subtitleStyle = const TextStyle(
      fontSize: 11.5,
      color: AppColors.textMuted,
      height: 1.3,
    );
    final Color statusColor = switch (service.lastStatus) {
      ServiceStatus.online => AppColors.online,
      ServiceStatus.offline => AppColors.textMuted,
      null => AppColors.textMuted,
    };

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
                icon: iconForService(service),
                emphasized: service.isFavorite,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusDot(isOnline: service.isOnline, size: 5),
                        const SizedBox(width: 5),
                        Text(
                          service.statusLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$deviceName · ${service.categoryLabel} · ${service.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(width: 4),
              SizedBox(
                width: 34,
                height: 34,
                child: PopupMenuButton<String>(
                  key: ValueKey<String>('service-menu-${service.id}'),
                  tooltip: '服务操作',
                  padding: EdgeInsets.zero,
                  color: AppColors.surfaceHigh,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
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
                      child: Text('编辑服务'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('删除服务'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
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
