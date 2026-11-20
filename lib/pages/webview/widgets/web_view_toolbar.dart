import 'package:material_ui/material_ui.dart';

/// Floating five-action toolbar shown above the bottom handle.
class WebViewToolbar extends StatelessWidget {
  const WebViewToolbar({
    super.key,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onSwitchService,
    required this.onMore,
    required this.onExit,
    this.canGoForward = false,
  });

  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchService;
  final VoidCallback onMore;
  final VoidCallback onExit;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SizedBox(
            height: 66,
            child: Material(
              elevation: 3,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: <Widget>[
                  _ToolbarAction(
                    key: const Key('webview-back'),
                    icon: Icons.arrow_back_rounded,
                    label: '后退',
                    onTap: onBack,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-forward'),
                    icon: Icons.arrow_forward_rounded,
                    label: '前进',
                    onTap: canGoForward ? onForward : null,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-refresh'),
                    icon: Icons.refresh_rounded,
                    label: '刷新',
                    onTap: onRefresh,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-service-switch'),
                    icon: Icons.dashboard_customize_rounded,
                    label: '服务',
                    onTap: onSwitchService,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-more'),
                    icon: Icons.more_horiz_rounded,
                    label: '更多',
                    onTap: onMore,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-exit'),
                    icon: Icons.close_rounded,
                    label: '退出',
                    onTap: onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: enabled
                    ? scheme.onSurface
                    : foreground.withValues(alpha: 0.38),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? foreground
                      : foreground.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact always-visible entry point for the toolbar.
class WebViewHandle extends StatelessWidget {
  const WebViewHandle({super.key, required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? '收起工具栏' : '展开工具栏',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        elevation: expanded ? 3 : 1,
        shape: StadiumBorder(
          side: BorderSide(
            color: expanded
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.36)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 104,
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  size: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  '工具栏',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
