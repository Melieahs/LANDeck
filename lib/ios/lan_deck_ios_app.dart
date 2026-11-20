import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../core/app_scope.dart';
import '../core/theme/theme_controller.dart';
import '../repositories/service_repository.dart';
import 'ios_shell.dart';
import 'ios_theme.dart';

/// Cupertino root used only on iOS. Android keeps [MaterialApp] untouched.
class LanDeckIosApp extends StatefulWidget {
  const LanDeckIosApp({
    super.key,
    required this.repository,
    required this.themeController,
  });

  final LanDeckRepository repository;
  final ThemeController themeController;

  @override
  State<LanDeckIosApp> createState() => _LanDeckIosAppState();
}

class _LanDeckIosAppState extends State<LanDeckIosApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (widget.themeController.mode == ThemeMode.system) {
      setState(() {});
    }
  }

  Brightness get _brightness {
    final Brightness system =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return switch (widget.themeController.mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => system,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (BuildContext context, Widget? _) {
        final Brightness brightness = _brightness;
        return AppScope(
          repository: widget.repository,
          child: ThemeScope(
            controller: widget.themeController,
            child: CupertinoApp(
              title: 'LANDeck',
              debugShowCheckedModeBanner: false,
              theme: IosTheme.build(brightness),
              home: const IosShell(),
            ),
          ),
        );
      },
    );
  }
}
