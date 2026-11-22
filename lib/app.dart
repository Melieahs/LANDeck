import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_scope.dart';
import 'core/theme/app_colors.dart';
import 'core/window/desktop_window.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'pages/main_shell.dart';
import 'repositories/service_repository.dart';
import 'routes/app_router.dart';
import 'widgets/window_title_bar.dart';

class LanDeckApp extends StatelessWidget {
  const LanDeckApp({super.key, required this.repository, this.themeController});

  final LanDeckRepository repository;
  final ThemeController? themeController;

  @override
  Widget build(BuildContext context) {
    final ThemeController controller =
        themeController ?? ThemeController.inMemory();
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? _) {
            final Brightness platformBrightness =
                WidgetsBinding.instance.platformDispatcher.platformBrightness;
            final Brightness effective = switch (controller.mode) {
              ThemeMode.light => Brightness.light,
              ThemeMode.dark => Brightness.dark,
              ThemeMode.system => platformBrightness,
            };
            AppColors.setBrightness(effective);

            return AppScope(
              repository: repository,
              child: ThemeScope(
                controller: controller,
                child: MaterialApp(
                  title: 'LANDeck',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightWith(
                    controller.dynamicColor ? lightDynamic : null,
                  ),
                  darkTheme: AppTheme.darkWith(
                    controller.dynamicColor ? darkDynamic : null,
                  ),
                  themeMode: controller.mode,
                  themeAnimationDuration: const Duration(milliseconds: 240),
                  themeAnimationCurve: Curves.easeOutCubic,
                  builder: (BuildContext context, Widget? child) {
                    // Keep the small legacy palette in sync with the resolved theme.
                    AppColors.setBrightness(Theme.of(context).brightness);
                    final Widget content = child ?? const SizedBox.shrink();
                    if (!usesCustomWindowChrome) {
                      return content;
                    }
                    return Column(
                      children: <Widget>[
                        const WindowTitleBar(),
                        Expanded(child: content),
                      ],
                    );
                  },
                  home: const MainShell(),
                  onGenerateRoute: AppRouter.onGenerateRoute,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
