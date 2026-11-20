import 'dart:ui';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A real UIKit Liquid Glass surface on iOS 26, with a Flutter material
/// fallback on older iOS versions and on non-iOS test hosts.
class IosGlassHeader extends StatefulWidget {
  const IosGlassHeader({
    super.key,
    required this.title,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onAdd;

  @override
  State<IosGlassHeader> createState() => _IosGlassHeaderState();
}

class _IosGlassHeaderState extends State<IosGlassHeader> {
  MethodChannel? _channel;

  bool get _usesNativeGlass =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('landeck/glass_header_$id')
      ..setMethodCallHandler((MethodCall call) async {
        if (call.method == 'add') {
          widget.onAdd();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_usesNativeGlass) {
      return UiKitView(
        viewType: 'landeck/glass_header',
        creationParams: <String, Object?>{'title': widget.title},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return _FallbackHeader(title: widget.title, onAdd: widget.onAdd);
  }
}

class _FallbackHeader extends StatelessWidget {
  const _FallbackHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = CupertinoTheme.brightnessOf(context);
    final Color background = brightness == Brightness.dark
        ? const Color(0xCC1C1C1E)
        : const Color(0xCCFFFFFF);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 54,
          padding: const EdgeInsets.only(left: 20, right: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x1A808080)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 40),
                onPressed: onAdd,
                child: const Icon(CupertinoIcons.add, size: 21),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
