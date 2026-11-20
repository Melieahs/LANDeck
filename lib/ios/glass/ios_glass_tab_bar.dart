import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IosGlassTabBar extends StatefulWidget {
  const IosGlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<IosGlassTabBar> createState() => _IosGlassTabBarState();
}

class _IosGlassTabBarState extends State<IosGlassTabBar> {
  MethodChannel? _channel;

  bool get _usesNativeGlass =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void didUpdateWidget(covariant IosGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _channel?.invokeMethod<void>('setSelected', widget.selectedIndex);
    }
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('landeck/glass_tabs_$id')
      ..setMethodCallHandler((MethodCall call) async {
        if (call.method == 'selected') {
          final Object? arguments = call.arguments;
          if (arguments is int && arguments != widget.selectedIndex) {
            widget.onSelected(arguments);
          }
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_usesNativeGlass) {
      return UiKitView(
        viewType: 'landeck/glass_tabs',
        creationParams: <String, Object?>{'selected': widget.selectedIndex},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return _FallbackTabBar(
      selectedIndex: widget.selectedIndex,
      onSelected: widget.onSelected,
    );
  }
}

class _FallbackTabBar extends StatelessWidget {
  const _FallbackTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color background = brightness == Brightness.dark
        ? const Color(0xCC1C1C1E)
        : const Color(0xCCFFFFFF);
    const List<(IconData, String)> items = <(IconData, String)>[
      (CupertinoIcons.house_fill, '首页'),
      (CupertinoIcons.antenna_radiowaves_left_right, '发现'),
      (CupertinoIcons.settings, '设置'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x1A808080)),
          ),
          child: Row(
            children: List<Widget>.generate(items.length, (int index) {
              final bool selected = index == selectedIndex;
              final Color color = selected
                  ? CupertinoColors.systemBlue.resolveFrom(context)
                  : CupertinoColors.secondaryLabel.resolveFrom(context);
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(items[index].$1, size: 21, color: color),
                      const SizedBox(height: 2),
                      Text(
                        items[index].$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
