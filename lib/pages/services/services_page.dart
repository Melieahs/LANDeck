import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/service_list_tile.dart';
import 'service_editor_page.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  Future<void> _addService(BuildContext context) async {
    await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => const ServiceEditorPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final List<Service> services = repository.services;
    return Scaffold(
      appBar: AppBar(
        title: const Text('全部服务'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('services-add'),
            onPressed: () => _addService(context),
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加服务',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: services.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.dns_outlined,
                            size: 42,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '还没有服务',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '添加设备后，在设备详情里填端口即可创建服务。',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _addService(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('添加服务'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: services.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final Service service = services[index];
                      return Card.outlined(
                        clipBehavior: Clip.antiAlias,
                        child: ServiceListTile(
                          service: service,
                          deviceName: repository.deviceNameFor(service),
                          onTap: () => Navigator.of(context).pushNamed<void>(
                            AppRoutes.webView,
                            arguments: WebViewArguments(serviceId: service.id),
                          ),
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
