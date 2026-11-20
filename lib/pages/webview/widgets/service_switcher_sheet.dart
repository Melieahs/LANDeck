import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/service.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/status_dot.dart';

/// Opens the service switcher and returns the newly selected service.
Future<Service?> showServiceSwitcherSheet(
  BuildContext context, {
  required List<Service> services,
  required Service current,
  required String Function(Service service) deviceNameFor,
}) {
  return showModalBottomSheet<Service>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (BuildContext context) {
      return ServiceSwitcherSheet(
        services: services,
        current: current,
        deviceNameFor: deviceNameFor,
      );
    },
  );
}

class ServiceSwitcherSheet extends StatefulWidget {
  const ServiceSwitcherSheet({
    super.key,
    required this.services,
    required this.current,
    required this.deviceNameFor,
  });

  final List<Service> services;
  final Service current;
  final String Function(Service service) deviceNameFor;

  @override
  State<ServiceSwitcherSheet> createState() => _ServiceSwitcherSheetState();
}

class _ServiceSwitcherSheetState extends State<ServiceSwitcherSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _query = '');
  }

  List<Service> get _filtered {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.services;
    }
    return widget.services
        .where((Service service) {
          final String haystack = <String>[
            service.name,
            service.url,
            service.address,
            service.categoryLabel,
            widget.deviceNameFor(service),
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double inset = media.viewInsets.bottom;
    final double available = media.size.height - media.padding.top - inset - 12;
    final double height = math.min(640.0, available * 0.94);
    final List<Service> filtered = _filtered;

    final Map<String, List<Service>> grouped = <String, List<Service>>{};
    for (final Service service in filtered) {
      grouped
          .putIfAbsent(widget.deviceNameFor(service), () => <Service>[])
          .add(service);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 9),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 10, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '切换服务',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '同一局域网 · ${widget.services.length} 个服务',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '关闭',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.only(left: 13, right: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (String value) =>
                                setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            cursorColor: Theme.of(context).colorScheme.primary,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '搜索名称、设备或 IP',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder:
                              (
                                BuildContext context,
                                TextEditingValue value,
                                Widget? child,
                              ) {
                                if (value.text.isEmpty) {
                                  return const SizedBox(width: 4);
                                }
                                return IconButton(
                                  onPressed: _clearSearch,
                                  tooltip: '清除搜索',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                );
                              },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 13, 20, 4),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '按设备分组',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} 个',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const _EmptyResult()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                          children: <Widget>[
                            for (final MapEntry<String, List<Service>> group
                                in grouped.entries) ...<Widget>[
                              _GroupHeader(
                                deviceName: group.key,
                                count: group.value.length,
                              ),
                              for (final Service service in group.value)
                                _ServiceRow(
                                  service: service,
                                  selected: service.id == widget.current.id,
                                  onTap: () =>
                                      Navigator.of(context).pop(service),
                                ),
                            ],
                          ],
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.deviceName, required this.count});

  final String deviceName;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.devices_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              deviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final Service service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.42)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('service-row-${service.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
            child: Row(
              children: <Widget>[
                ServiceIconBadge(
                  icon: iconForService(service),
                  size: 38,
                  emphasized: selected,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      StatusDot(isOnline: service.isOnline, size: 5),
                      const SizedBox(width: 5),
                      Text(
                        service.statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: service.isOnline
                              ? AppColors.online
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 30,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: 10),
          Text(
            '没有匹配的服务',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 3),
          Text(
            '试试服务名称、设备或 IP 地址',
            style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
