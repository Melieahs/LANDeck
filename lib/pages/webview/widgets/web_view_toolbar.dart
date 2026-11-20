import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

/// Floating five-action toolbar shown above the bottom handle.
class WebViewToolbar extends StatelessWidget {
  const WebViewToolbar({
    super.key,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onSwitchService,
    required this.onMore,
    this.canGoForward = false,
  });

  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchService;
  final VoidCallback onMore;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
    final Color foreground =
        enabled ? AppColors.textSecondary : AppColors.textMuted;

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
                    ? AppColors.textPrimary
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
  const WebViewHandle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? '收起工具栏' : '展开工具栏',
      child: Material(
        color: AppColors.surfaceSoft.withValues(alpha: 0.92),
        shape: StadiumBorder(
          side: BorderSide(
            color: expanded
                ? AppColors.accent.withValues(alpha: 0.36)
                : AppColors.border,
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
                const Icon(
                  Icons.tune_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 5),
                const Text(
                  '工具栏',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
