import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Actions available from the circular WebView handle. They intentionally
/// mirror the existing toolbar, so the wheel cannot grow unrelated features.
enum WebViewQuickAction { back, refresh, switchService, more, exit }

class QuickActionItem {
  const QuickActionItem({
    required this.action,
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  final WebViewQuickAction action;
  final IconData icon;
  final String label;
  final bool enabled;
}

/// Upper-half radial menu. Keeping the items above the handle means it never
/// covers the system navigation area and stays inside narrow phone screens.
class QuickActionWheel extends StatelessWidget {
  const QuickActionWheel({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.size = 304,
  });

  final List<QuickActionItem> items;
  final int? selectedIndex;
  final double size;

  static const List<double> itemAngles = <double>[-165, -127.5, -90, -52.5, -15];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double radius = size * 0.37;
    final Offset center = Offset(size / 2, size / 2);
    final double itemWidth = (size * 0.22).clamp(58.0, 76.0);
    const double itemHeight = 52;

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
          );
        },
        child: SizedBox(
          key: const Key('quick-action-wheel'),
          width: size,
          height: size,
          child: Stack(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Positioned(
                  left:
                      center.dx +
                      math.cos(itemAngles[i] * math.pi / 180) * radius -
                      itemWidth / 2,
                  top:
                      center.dy +
                      math.sin(itemAngles[i] * math.pi / 180) * radius -
                      itemHeight / 2,
                  child: _QuickActionChip(
                    item: items[i],
                    selected: selectedIndex == i,
                    scheme: scheme,
                    width: itemWidth,
                    height: itemHeight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.item,
    required this.selected,
    required this.scheme,
    required this.width,
    required this.height,
  });

  final QuickActionItem item;
  final bool selected;
  final ColorScheme scheme;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh.withValues(alpha: 0.96);
    final Color foreground = selected
        ? scheme.onPrimaryContainer
        : item.enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: item.enabled,
      selected: selected,
      label: item.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.72)
                : scheme.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(item.icon, size: 20, color: foreground),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: foreground,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
