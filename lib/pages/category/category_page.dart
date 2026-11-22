import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../models/device_category.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/service_list_tile.dart';
import '../services/service_editor_page.dart';
import '../../widgets/empty_state.dart';

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
    final String title = category == DeviceCategory.all
        ? '全部服务'
        : category.label;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('category-add-service'),
            tooltip: '添加服务',
            onPressed: () => _addService(context),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kListPageMaxWidth),
            child: services.isEmpty
                ? _EmptyCategory(
                    category: category,
                    onAdd: () => _addService(context),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    itemCount: services.length + 1,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                          child: Text(
                            '${services.length} 个服务',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }
                      final Service service = services[index - 1];
                      return ServiceListTile(
                        key: ValueKey<String>('category-service-${service.id}'),
                        service: service,
                        deviceName: repository.deviceNameFor(service),
                        onTap: () => Navigator.of(context).pushNamed<void>(
                          AppRoutes.webView,
                          arguments: WebViewArguments(serviceId: service.id),
                        ),
                      );
                    },
                  ),
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
    return EmptyState(
      icon: iconForCategory(category),
      title: category == DeviceCategory.all ? '还没有添加服务' : '该分类下还没有服务',
      message: '服务只来自你手动添加或扫描确认的记录。',
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加服务'),
      ),
    );
  }
}
