import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'web_view_quick_actions.dart';

/// Floating six-action toolbar shown above the bottom circular handle.
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
                    key: const Key('webview-exit'),
                    icon: Icons.close_rounded,
                    label: '退出',
                    onTap: onExit,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-more'),
                    icon: Icons.more_horiz_rounded,
                    label: '更多',
                    onTap: onMore,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-service-switch'),
                    icon: Icons.dashboard_customize_rounded,
                    label: '服务',
                    onTap: onSwitchService,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-refresh'),
                    icon: Icons.refresh_rounded,
                    label: '刷新',
                    onTap: onRefresh,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-forward'),
                    icon: Icons.arrow_forward_rounded,
                    label: '前进',
                    onTap: canGoForward ? onForward : null,
                  ),
                  _ToolbarAction(
                    key: const Key('webview-back'),
                    icon: Icons.arrow_back_rounded,
                    label: '后退',
                    onTap: onBack,
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
///
/// Single tap toggles the toolbar. Long press opens a radial shortcut menu;
/// drag away from the centre to choose, release to execute, or drag back to
/// the centre to cancel.
class WebViewHandle extends StatefulWidget {
  const WebViewHandle({
    super.key,
    required this.expanded,
    required this.onTap,
    required this.onBack,
    required this.onRefresh,
    required this.onSwitchService,
    required this.onMore,
    required this.onExit,
  });

  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchService;
  final VoidCallback onMore;
  final VoidCallback onExit;

  @override
  State<WebViewHandle> createState() => _WebViewHandleState();
}

class _WebViewHandleState extends State<WebViewHandle> {
  OverlayEntry? _wheelEntry;
  Offset? _center;
  int? _selectedIndex;

  bool get _wheelOpen => _wheelEntry != null;

  List<QuickActionItem> get _items => <QuickActionItem>[
    QuickActionItem(
      action: WebViewQuickAction.back,
      icon: Icons.arrow_back_rounded,
      label: '后退',
    ),
    QuickActionItem(
      action: WebViewQuickAction.refresh,
      icon: Icons.refresh_rounded,
      label: '刷新',
    ),
    QuickActionItem(
      action: WebViewQuickAction.switchService,
      icon: Icons.dashboard_customize_rounded,
      label: '服务',
    ),
    QuickActionItem(
      action: WebViewQuickAction.more,
      icon: Icons.more_horiz_rounded,
      label: '更多',
    ),
    QuickActionItem(
      action: WebViewQuickAction.exit,
      icon: Icons.close_rounded,
      label: '退出',
    ),
  ];

  @override
  void dispose() {
    _removeWheel();
    super.dispose();
  }

  void _startWheel(LongPressStartDetails details) {
    if (_wheelOpen) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    _center = box.localToGlobal(box.size.center(Offset.zero));
    _selectedIndex = null;
    _wheelEntry = OverlayEntry(builder: _buildWheel);
    Overlay.of(context, rootOverlay: true).insert(_wheelEntry!);
    HapticFeedback.mediumImpact();
    _updateSelection(details.globalPosition);
  }

  Widget _buildWheel(BuildContext context) {
    final Offset? center = _center;
    if (center == null) {
      return const SizedBox.shrink();
    }
    final double available = MediaQuery.sizeOf(context).width - 12;
    final double size = math.min(320, available);
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: QuickActionWheel(
        items: _items,
        selectedIndex: _selectedIndex,
        size: size,
      ),
    );
  }

  void _updateSelection(Offset globalPosition) {
    if (!_wheelOpen || _center == null) {
      return;
    }
    final Offset delta = globalPosition - _center!;
    int? next;
    if (delta.distance >= 30 && delta.dy <= 22) {
      double best = -2;
      for (int i = 0; i < QuickActionWheel.itemAngles.length; i++) {
        final double angle = QuickActionWheel.itemAngles[i] * math.pi / 180;
        final double alignment =
            (math.cos(angle) * delta.dx + math.sin(angle) * delta.dy) /
            delta.distance;
        if (alignment > best) {
          best = alignment;
          next = i;
        }
      }
      if (best < 0.2) {
        next = null;
      }
    }
    if (next == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = next);
    _wheelEntry?.markNeedsBuild();
    if (next != null) {
      HapticFeedback.selectionClick();
    }
  }

  void _finishWheel() {
    final int? index = _selectedIndex;
    final List<QuickActionItem> items = _items;
    _removeWheel();
    if (index == null || index >= items.length) {
      return;
    }
    final QuickActionItem item = items[index];
    if (!item.enabled) {
      return;
    }
    HapticFeedback.lightImpact();
    switch (item.action) {
      case WebViewQuickAction.back:
        widget.onBack();
        break;
      case WebViewQuickAction.refresh:
        widget.onRefresh();
        break;
      case WebViewQuickAction.switchService:
        widget.onSwitchService();
        break;
      case WebViewQuickAction.more:
        widget.onMore();
        break;
      case WebViewQuickAction.exit:
        widget.onExit();
        break;
    }
  }

  void _removeWheel() {
    _wheelEntry?.remove();
    _wheelEntry = null;
    if (mounted && _selectedIndex != null) {
      setState(() => _selectedIndex = null);
    } else {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.expanded ? '收起工具栏' : '单击展开 · 长按快捷操作',
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPressStart: _startWheel,
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
          _updateSelection(details.globalPosition);
        },
        onLongPressEnd: (_) => _finishWheel(),
        child: Material(
          elevation: widget.expanded ? 3 : 1,
          shape: CircleBorder(
            side: BorderSide(
              color: widget.expanded
                  ? scheme.primary.withValues(alpha: 0.36)
                  : scheme.outlineVariant,
            ),
          ),
          color: widget.expanded
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: widget.expanded
                  ? scheme.onPrimaryContainer
                  : scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
