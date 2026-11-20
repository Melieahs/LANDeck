import 'package:material_ui/material_ui.dart';

import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/sort_menu.dart';
import '../../../widgets/status_dot.dart';

enum _FavoriteSort { name, status, device }

class FavoritesSection extends StatefulWidget {
  const FavoritesSection({
    super.key,
    required this.services,
    required this.deviceNameFor,
    required this.onOpenService,
    required this.onAddService,
  });

  final List<Service> services;
  final String Function(Service service) deviceNameFor;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onAddService;

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  _FavoriteSort _sort = _FavoriteSort.name;

  List<Service> get _sorted {
    final List<Service> list = List<Service>.of(widget.services);
    switch (_sort) {
      case _FavoriteSort.name:
        list.sort(
          (Service a, Service b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _FavoriteSort.status:
        list.sort((Service a, Service b) {
          if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _FavoriteSort.device:
        list.sort((Service a, Service b) {
          final int byDevice = widget
              .deviceNameFor(a)
              .toLowerCase()
              .compareTo(widget.deviceNameFor(b).toLowerCase());
          return byDevice != 0
              ? byDevice
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final List<Service> services = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '收藏',
          trailing: services.isEmpty ? null : '${services.length} 个常用服务',
          action: services.isEmpty
              ? null
              : SortMenu<_FavoriteSort>(
                  current: _sort,
                  onSelected: (_FavoriteSort value) =>
                      setState(() => _sort = value),
                  choices: const <SortChoice<_FavoriteSort>>[
                    SortChoice<_FavoriteSort>(
                      value: _FavoriteSort.name,
                      label: '按名称',
                    ),
                    SortChoice<_FavoriteSort>(
                      value: _FavoriteSort.status,
                      label: '按在线状态',
                    ),
                    SortChoice<_FavoriteSort>(
                      value: _FavoriteSort.device,
                      label: '按设备',
                    ),
                  ],
                ),
        ),
        if (services.isEmpty)
          _EmptyFavorites(onAddService: widget.onAddService)
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
                onTap: () => widget.onOpenService(service),
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
