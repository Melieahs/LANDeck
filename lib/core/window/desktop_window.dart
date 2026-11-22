import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

/// The window chrome is only replaced on Windows: the custom Material title
/// bar needs a real desktop window to drive.
bool get usesCustomWindowChrome =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

/// Creates the Windows window with the system caption removed so
/// [WindowTitleBar] can draw the whole title bar itself.
Future<void> setupDesktopWindow() async {
  if (!usesCustomWindowChrome) {
    return;
  }
  await windowManager.ensureInitialized();
  const WindowOptions options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 600),
    center: true,
    title: 'LANDeck',
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
