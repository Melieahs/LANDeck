import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/status_dot.dart';

class FavoritesSection extends StatelessWidget {
  const FavoritesSection({
    super.key,
    required this.services,
    required this.onOpenService,
    required this.onAddService,
  });

  final List<Service> services;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '收藏',
          trailing: services.isEmpty ? null : '${services.length} 个常用服务',
        ),
        if (services.isEmpty)
          _EmptyFavorites(onAddService: onAddService)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: services.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 128,
            ),
            itemBuilder: (BuildContext context, int index) {
              final Service service = services[index];
              return _FavoriteCard(
                key: ValueKey<String>('favorite-${service.id}'),
                service: service,
                onTap: () => onOpenService(service),
              );
            },
          ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({super.key, required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ServiceIconBadge(
                    icon: iconForService(service),
                    size: 38,
                    emphasized: true,
                  ),
                  const Spacer(),
                  StatusDot(isOnline: service.isOnline, size: 6),
                ],
              ),
              const Spacer(),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                service.categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.onAddService});

  final VoidCallback onAddService;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.star_border_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '还没有收藏的服务。',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: onAddService,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              '添加',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
