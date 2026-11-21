import 'package:material_ui/material_ui.dart';

import '../../models/service.dart';
import '../../core/app_scope.dart';
import '../native_module.dart';

/// A real, offline native module that presents the service's locally stored
/// metadata. It is intentionally small: the native module framework is the
/// feature, not a fabricated device-control implementation.
class ServiceOverviewNativeModule extends NativeModule {
  const ServiceOverviewNativeModule();

  static const String moduleId = 'builtin.service-overview';

  @override
  String get id => moduleId;

  @override
  String get name => '服务概览';

  @override
  String get version => '1.0.0';

  @override
  String get description => '使用 Flutter 原生界面显示服务、设备与状态信息，不依赖 WebView。';

  @override
  bool supports(Service service) => service.hasUrl;

  @override
  Widget buildPage(BuildContext context, Service service) {
    return _ServiceOverview(serviceId: service.id);
  }
}

class _ServiceOverview extends StatelessWidget {
  const _ServiceOverview({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final services = AppScope.of(context);
    final Service? service = services.serviceById(serviceId);
    if (service == null) {
      return const Center(child: Text('服务不存在或已被删除'));
    }
    final String deviceName = services.deviceNameFor(service);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.dns_rounded,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            service.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoRow(label: '访问地址', value: service.url),
                const SizedBox(height: 10),
                _InfoRow(label: '所属设备', value: deviceName),
                const SizedBox(height: 10),
                _InfoRow(label: '分类', value: service.categoryLabel),
                const SizedBox(height: 10),
                _InfoRow(label: '最近状态', value: service.statusLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '此页面由内置原生模块「服务概览」呈现。模块只读取本机已保存的数据，不会修改服务或访问网络。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
