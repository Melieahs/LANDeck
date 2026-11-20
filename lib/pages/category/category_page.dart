import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/feedback.dart';
import '../../models/device_category.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/service_list_tile.dart';
import '../../widgets/status_dot.dart';
import '../services/service_editor_page.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.category});

  final DeviceCategory category;

  Future<void> _addService(BuildContext context) async {
    final Service? saved = await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => ServiceEditorPage(
          initialCategory: category == DeviceCategory.all ? null : category,
        ),
      ),
    );
    if (saved != null && context.mounted) {
      showAppSnackBar(context, '已添加「${saved.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final List<Service> services = repository.servicesForCategory(category);
    final int onlineCount =
        services.where((Service service) => service.isOnline).length;
    final String title =
        category == DeviceCategory.all ? '全部服务' : category.label;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: <Widget>[
                      _BackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  iconForCategory(category),
                                  size: 17,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                Text(
                                  '${services.length} 个服务',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                if (services.isNotEmpty) ...<Widget>[
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  StatusDot(
                                    isOnline: onlineCount > 0,
                                    size: 5,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$onlineCount 在线',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>('category-add-service'),
                        onPressed: () => _addService(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.accentSoft,
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: services.isEmpty
                      ? _EmptyCategory(
                          category: category,
                          onAdd: () => _addService(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                          itemCount: services.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final Service service = services[index];
                            return ServiceListTile(
                              key: ValueKey<String>(
                                'category-service-${service.id}',
                              ),
                              service: service,
                              deviceName: repository.deviceNameFor(service),
                              onTap: () => Navigator.of(context).pushNamed<void>(
                                AppRoutes.webView,
                                arguments: WebViewArguments(
                                  serviceId: service.id,
                                ),
                              ),
                            );
                          },
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.category, required this.onAdd});

  final DeviceCategory category;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                iconForCategory(category),
                size: 30,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              category == DeviceCategory.all ? '还没有添加服务' : '该分类下还没有服务',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '服务只来自你手动添加或扫描确认的记录。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('添加服务'),
            ),
          ],
        ),
      ),
    );
  }
}
