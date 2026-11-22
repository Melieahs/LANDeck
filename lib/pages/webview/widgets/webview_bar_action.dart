import 'package:material_ui/material_ui.dart';

/// Compact action button for the web viewer top bar.
///
/// The bar sits on `surfaceContainer`; each icon gets its own 40px tonal
/// container one step lighter, so the actions read as controls instead of
/// bare glyphs on a flat strip. The footprint matches the previous plain
/// [IconButton] (40px visual, 48px tap target) and the bar height is untouched.
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        disabledBackgroundColor: scheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
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
    leading: leading,
    title: title,
    actions: actions,
  );
}
