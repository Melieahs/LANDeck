import 'package:material_ui/material_ui.dart';

import '../../../models/service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';

/// Home favorites grid with a manual order the user controls by dragging.
class FavoritesSection extends StatefulWidget {
  const FavoritesSection({
    super.key,
    required this.services,
    required this.deviceNameFor,
    required this.onOpenService,
    required this.onAddService,
    required this.onReorder,
  });

  final List<Service> services;
  final String Function(Service service) deviceNameFor;
  final ValueChanged<Service> onOpenService;
  final VoidCallback onAddService;
  final ValueChanged<List<Service>> onReorder;

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  late List<Service> _services = widget.services;
  bool _editing = false;

  @override
  void didUpdateWidget(FavoritesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<String> next = widget.services
        .map((Service service) => service.id)
        .toList();
    final List<String> shown = _services
        .map((Service service) => service.id)
        .toList();
    final bool changed =
        next.length != shown.length ||
        Iterable<int>.generate(next.length)
            .any((int index) => next[index] != shown[index]);
    if (changed) {
      _services = widget.services;
    }
  }

  void _move(Service dragged, int targetIndex) {
    final int from = _services.indexWhere(
      (Service service) => service.id == dragged.id,
    );
    if (from < 0 || from == targetIndex) {
      return;
    }
    final List<Service> next = List<Service>.of(_services);
    final Service item = next.removeAt(from);
    next.insert(targetIndex.clamp(0, next.length), item);
    setState(() => _services = next);
    widget.onReorder(next);
  }

  Widget _editButton() {
    return TextButton(
      key: const Key('favorites-edit'),
      onPressed: () => setState(() => _editing = !_editing),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(_editing ? '完成' : '编辑'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Service> services = _services;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '收藏',
          trailing: services.isEmpty
              ? null
              : _editing
              ? '拖动卡片调整顺序'
              : '${services.length} 个常用服务',
          action: services.isEmpty ? null : _editButton(),
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
              final Widget card = _FavoriteCard(
                key: ValueKey<String>('favorite-${service.id}'),
                service: service,
                editing: _editing,
                onTap: _editing ? null : () => widget.onOpenService(service),
              );
              if (!_editing) {
                return card;
              }
              return DragTarget<Service>(
                onWillAcceptWithDetails: (DragTargetDetails<Service> details) =>
                    details.data.id != service.id,
                onAcceptWithDetails: (DragTargetDetails<Service> details) =>
                    _move(details.data, index),
                builder:
                    (
                      BuildContext context,
                      List<Service?> candidate,
                      List<Object?> rejected,
                    ) {
                      return Draggable<Service>(
                        data: service,
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: SizedBox(
                          width: MediaQuery.sizeOf(context).width * 0.42,
                          child: card,
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: card),
                        child: AnimatedScale(
                          scale: candidate.isNotEmpty ? 0.96 : 1,
                          duration: const Duration(milliseconds: 120),
                          child: card,
                        ),
                      );
                    },
              );
            },
          ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    super.key,
    required this.service,
    required this.onTap,
    this.editing = false,
  });

  final Service service;
  final VoidCallback? onTap;
  final bool editing;

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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (editing) ...<Widget>[
                const SizedBox(width: 4),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
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
