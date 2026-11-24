import 'package:flutter/material.dart';

/// Compact action button for the web viewer top bar.
///
/// A 40px circle on `surfaceContainerHighest`, one tonal step above the bar.
/// The widget draws the circle itself instead of using [IconButton]: the
/// framework's IconButton keeps a 48px footprint even with a 40px shape, which
/// leaves a visible gap between neighbours. Drawing a tight 40px circle lets
/// the actions sit edge to edge.
class WebViewBarAction extends StatelessWidget {
  const WebViewBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerHighest.withOpacity(0.4),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared top bar for the web viewer pages.
///
/// A single container-coloured surface (one tonal step above the page) keeps
/// the strip from blending into a flat black/dark page; the title stack uses
/// the same compact rhythm as the 40px action buttons.
AppBar webViewerAppBar({
  required Color surface,
  required Widget leading,
  required Widget title,
  required List<Widget> actions,
}) {
  return AppBar(
    backgroundColor: surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    leadingWidth: 56,
    // Push the exit button in by 4px without moving the title: the bar used
    // to spend 48 + 16 (default titleSpacing) on the leading slot, which is
    // what 56 + 8 keeps exactly.
    titleSpacing: 8,
    // AppBar hands the leading slot a tight 56×toolbar constraint; a fixed
    // 40px box keeps the exit button the same size as the actions.
    leading: SizedBox(
      width: 56,
      height: 40,
      child: Center(child: leading),
    ),
    title: title,
    actions: actions,
  );
}
