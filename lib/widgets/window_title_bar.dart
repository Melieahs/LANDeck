import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Material 3 window title bar used on Windows in place of the system caption.
///
/// The whole strip is a drag handle; double-clicking toggles maximize. Window
/// actions sit on the right, mirroring the Windows order (minimize, maximize,
/// close) so muscle memory keeps working.
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  static const double height = 44;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar>
    with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximizedState() async {
    try {
      final bool maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } on Object {
      // Widget tests have no window manager channel; the title bar is inert.
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  Future<void> _toggleMaximize() async {
    if (_maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncMaximizedState();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainer,
      child: Container(
        height: WindowTitleBar.height,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant, width: 1),
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          onDoubleTap: _toggleMaximize,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 14),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.layers_rounded,
                  size: 14,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'LANDeck',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              _WindowActionButton(
                icon: Icons.remove_rounded,
                tooltip: '最小化',
                onPressed: windowManager.minimize,
              ),
              _WindowActionButton(
                icon: _maximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                tooltip: _maximized ? '还原' : '最大化',
                onPressed: _toggleMaximize,
              ),
              _WindowActionButton(
                icon: Icons.close_rounded,
                tooltip: '关闭',
                danger: true,
                onPressed: windowManager.close,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowActionButton extends StatefulWidget {
  const _WindowActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final bool danger;

  @override
  State<_WindowActionButton> createState() => _WindowActionButtonState();
}

class _WindowActionButtonState extends State<_WindowActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = _hovered
        ? (widget.danger
              ? colors.error
              : colors.onSurface.withOpacity(0.08))
        : Colors.transparent;
    final Color foreground = _hovered && widget.danger
        ? colors.onError
        : colors.onSurfaceVariant;
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPressed(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 46,
            height: WindowTitleBar.height,
            color: background,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 17, color: foreground),
          ),
        ),
      ),
    );
  }
}
