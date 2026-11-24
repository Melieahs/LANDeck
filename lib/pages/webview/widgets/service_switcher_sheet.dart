import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/service.dart';
import '../../../models/service_mode.dart';
import '../../../native/native_module_registry.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/status_dot.dart';

/// A selected service plus the presentation the user asked for.
class ServiceSelection {
  const ServiceSelection({required this.service, required this.mode});

  final Service service;
  final ServiceMode mode;
}

/// Opens the service switcher and returns the selected service and mode.
Future<ServiceSelection?> showServiceSwitcherSheet(
  BuildContext context, {
  required List<Service> services,
  required Service current,
  required ServiceMode currentMode,
  required String Function(Service service) deviceNameFor,
  NativeModuleRegistry? registry,
  Set<String> openServiceIds = const <String>{},
}) {
  return showModalBottomSheet<ServiceSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (BuildContext context) {
      return ServiceSwitcherSheet(
        services: services,
        current: current,
        currentMode: currentMode,
        deviceNameFor: deviceNameFor,
        registry: registry ?? NativeModuleRegistry.instance,
        openServiceIds: openServiceIds,
      );
    },
  );
}

class ServiceSwitcherSheet extends StatefulWidget {
  const ServiceSwitcherSheet({
    super.key,
    required this.services,
    required this.current,
    required this.currentMode,
    required this.deviceNameFor,
    required this.registry,
    this.openServiceIds = const <String>{},
  });

  final List<Service> services;
  final Service current;
  final ServiceMode currentMode;
  final String Function(Service service) deviceNameFor;
  final NativeModuleRegistry registry;
  final Set<String> openServiceIds;

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
    final List<Service> sorted = List<Service>.of(widget.services)
      ..sort(_compareRecent);
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return sorted;
    }
    return sorted
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

  static int _compareRecent(Service a, Service b) {
    final DateTime? left = a.lastOpenedAt;
    final DateTime? right = b.lastOpenedAt;
    if (left != null || right != null) {
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      final int byTime = right.compareTo(left);
      if (byTime != 0) {
        return byTime;
      }
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData media = MediaQuery.of(context);
    final double inset = media.viewInsets.bottom;
    final double available = media.size.height - media.padding.top - inset - 12;
    final double height = math.min(640.0, available * 0.94);
    final List<Service> filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                _DragHandle(color: scheme.onSurfaceVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
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
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '最近使用 · ${widget.services.length} 个服务',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
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
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      key: const Key('service-switcher-search'),
                      controller: _controller,
                      onChanged: (String value) =>
                          setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: scheme.primary,
                      style: TextStyle(fontSize: 14, color: scheme.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        hintText: '搜索名称、设备或 IP',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 42,
                          minHeight: 44,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder:
                              (
                                BuildContext context,
                                TextEditingValue value,
                                Widget? child,
                              ) {
                                if (value.text.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  onPressed: _clearSearch,
                                  tooltip: '清除搜索',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                );
                              },
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 44,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '最近使用',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length} 个',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const _EmptyResult()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          children: <Widget>[
                            for (final Service service in filtered)
                              _ServiceRow(
                                service: service,
                                deviceName: widget.deviceNameFor(service),
                                selected: service.id == widget.current.id,
                                open: widget.openServiceIds.contains(
                                  service.id,
                                ),
                                selectedMode: widget.currentMode,
                                nativeAvailable:
                                    widget.registry.linkedModule(service) !=
                                    null,
                                defaultMode: service.defaultMode,
                                onSelect: (ServiceMode mode) =>
                                    Navigator.of(context).pop(
                                      ServiceSelection(
                                        service: service,
                                        mode: mode,
                                      ),
                                    ),
                              ),
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

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: color.withOpacity(0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.deviceName,
    required this.selected,
    required this.selectedMode,
    required this.nativeAvailable,
    required this.defaultMode,
    required this.onSelect,
    this.open = false,
  });

  final Service service;
  final String deviceName;
  final bool selected;
  final ServiceMode selectedMode;
  final bool nativeAvailable;
  final ServiceMode defaultMode;
  final ValueChanged<ServiceMode> onSelect;

  /// True when the service already has a live tab in the background.
  final bool open;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ServiceMode openMode = nativeAvailable
        ? defaultMode
        : ServiceMode.web;
    return Material(
      // A soft tint of the brand colour marks the active row without the
      // violet cast that secondaryContainer gives in dark mode.
      color: selected
          ? scheme.primary.withOpacity(0.12)
          : Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('service-row-${service.id}'),
        onTap: () => onSelect(openMode),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: <Widget>[
              ServiceIconBadge(
                icon: iconForService(service),
                size: 40,
                emphasized: selected,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$deviceName · ${service.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (nativeAvailable) ...<Widget>[
                      const SizedBox(height: 6),
                      _ModeToggle(
                        serviceId: service.id,
                        selected: selected ? selectedMode : null,
                        onSelect: onSelect,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: scheme.primary,
                )
              else
                Tooltip(
                  message: open ? '存活 · 有后台页面' : '无后台页面',
                  child: StatusDot(isOnline: open, size: 7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.serviceId,
    required this.selected,
    required this.onSelect,
  });

  final String serviceId;
  final ServiceMode? selected;
  final ValueChanged<ServiceMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      children: <Widget>[
        for (final ServiceMode mode in ServiceMode.values)
          InkWell(
            key: ValueKey<String>('service-mode-$serviceId-${mode.name}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected == mode
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    mode == ServiceMode.web
                        ? Icons.language_rounded
                        : Icons.widgets_rounded,
                    size: 13,
                    color: selected == mode
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: selected == mode
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
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

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 30,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            '没有匹配的服务',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '试试服务名称、设备或 IP 地址',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
