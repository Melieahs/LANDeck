import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
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
  });

  final List<Service> services;
  final Service current;
  final ServiceMode currentMode;
  final String Function(Service service) deviceNameFor;
  final NativeModuleRegistry registry;

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
                              '最近使用 · ${widget.services.length} 个服务',
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
                  child: SizedBox(
                    height: 46,
                    child: TextField(
                      key: const Key('service-switcher-search'),
                      controller: _controller,
                      onChanged: (String value) =>
                          setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: Theme.of(context).colorScheme.primary,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        hintText: '搜索名称、设备或 IP',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 19,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
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
                                    size: 17,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 13, 20, 4),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '最近使用',
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
                            for (final Service service in filtered)
                              _ServiceRow(
                                service: service,
                                deviceName: widget.deviceNameFor(service),
                                selected: service.id == widget.current.id,
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

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.deviceName,
    required this.selected,
    required this.selectedMode,
    required this.nativeAvailable,
    required this.defaultMode,
    required this.onSelect,
  });

  final Service service;
  final String deviceName;
  final bool selected;
  final ServiceMode selectedMode;
  final bool nativeAvailable;
  final ServiceMode defaultMode;
  final ValueChanged<ServiceMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ServiceMode openMode = nativeAvailable ? defaultMode : ServiceMode.web;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.42)
                : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('service-row-${service.id}'),
          onTap: () => onSelect(openMode),
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
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$deviceName · ${service.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
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
                    size: 18,
                    color: scheme.primary,
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
                              : scheme.onSurfaceVariant,
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
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelect(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: selected == mode
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    mode == ServiceMode.web
                        ? Icons.language_rounded
                        : Icons.widgets_rounded,
                    size: 12,
                    color: selected == mode
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: selected == mode
                          ? scheme.onPrimary
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
