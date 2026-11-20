import 'package:material_ui/material_ui.dart';

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
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 92,
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ServiceIconBadge(
                icon: iconForService(service),
                size: 40,
                emphasized: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        StatusDot(isOnline: service.isOnline, size: 5),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            service.isOnline ? '在线' : service.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
    return Card.outlined(
      child: ListTile(
        leading: const Icon(Icons.star_outline_rounded),
        title: const Text('还没有收藏的服务'),
        subtitle: const Text('在服务编辑页打开收藏，即可出现在这里。'),
        trailing: TextButton(onPressed: onAddService, child: const Text('添加')),
      ),
    );
  }
}
