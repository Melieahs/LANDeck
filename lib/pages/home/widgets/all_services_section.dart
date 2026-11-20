import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_list_tile.dart';

class AllServicesSection extends StatelessWidget {
  const AllServicesSection({
    super.key,
    required this.services,
    required this.query,
    required this.deviceNameFor,
    required this.onOpenService,
    required this.onClearSearch,
    required this.onAddService,
    required this.onScan,
  });

  final List<Service> services;
  final String query;
  final String Function(Service service) deviceNameFor;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onClearSearch;
  final VoidCallback onAddService;
  final VoidCallback onScan;

  bool get _isSearching => query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '全部服务',
          trailing: _isSearching ? '${services.length} 个结果' : '共 ${services.length} 个',
          action: IconButton(
            key: const ValueKey<String>('all-services-add'),
            onPressed: onAddService,
            tooltip: '添加服务',
            icon: const Icon(Icons.add_rounded, size: 17),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.accent,
              backgroundColor: AppColors.accentSoft,
            ),
          ),
        ),
        if (services.isEmpty)
          _isSearching
              ? _EmptySearchState(onClearSearch: onClearSearch)
              : _EmptyServicesState(onAddService: onAddService, onScan: onScan)
        else
          for (int index = 0; index < services.length; index++) ...<Widget>[
            ServiceListTile(
              key: ValueKey<String>('service-${services[index].id}'),
              service: services[index],
              deviceName: deviceNameFor(services[index]),
              onTap: () => onOpenService(services[index]),
            ),
            if (index != services.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({required this.onAddService, required this.onScan});

  final VoidCallback onAddService;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.dns_outlined,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 11),
          const Text(
            '还没有添加服务',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '扫描当前局域网，或手动填写一个 Web 服务地址。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.radar_rounded, size: 17),
                label: const Text('扫描局域网'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF04101F),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAddService,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('手动添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.search_off_rounded,
            size: 28,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            '没有找到匹配的服务',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '试试服务名称、设备或 IP 地址',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onClearSearch,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text(
              '清除搜索',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
