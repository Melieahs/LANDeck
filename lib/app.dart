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

EdgeInsets _scaleInsets(EdgeInsets insets, double factor) {
  return EdgeInsets.fromLTRB(
    insets.left * factor,
    insets.top * factor,
    insets.right * factor,
    insets.bottom * factor,
  );
}

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
                  theme: AppTheme.schemeFor(
                    brightness: Brightness.light,
                    dynamicScheme: controller.dynamicColor
                        ? lightDynamic
                        : null,
                    seedColor: controller.seedColor,
                    amoled: controller.amoled,
                  ),
                  darkTheme: AppTheme.schemeFor(
                    brightness: Brightness.dark,
                    dynamicScheme: controller.dynamicColor
                        ? darkDynamic
                        : null,
                    seedColor: controller.seedColor,
                    amoled: controller.amoled,
                  ),
                  themeMode: controller.mode,
                  themeAnimationDuration: const Duration(milliseconds: 240),
                  themeAnimationCurve: Curves.easeOutCubic,
                  builder: (BuildContext context, Widget? child) {
                    // Keep the small legacy palette in sync with the resolved theme.
                    AppColors.setBrightness(Theme.of(context).brightness);
                    Widget content = child ?? const SizedBox.shrink();
                    if (controller.textScale != 1) {
                      content = MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(controller.textScale),
                        ),
                        child: content,
                      );
                    }
                    final double uiScale = controller.effectiveUiScale;
                    if (uiScale != 1) {
                      final MediaQueryData mq = MediaQuery.of(context);
                      final double inverse = 1 / uiScale;
                      content = MediaQuery(
                        data: mq.copyWith(
                          size: mq.size * inverse,
                          devicePixelRatio: mq.devicePixelRatio * uiScale,
                          padding: _scaleInsets(mq.padding, inverse),
                          viewPadding: _scaleInsets(mq.viewPadding, inverse),
                          viewInsets: _scaleInsets(mq.viewInsets, inverse),
                        ),
                        child: Transform.scale(
                          scale: uiScale,
                          alignment: Alignment.topLeft,
                          child: content,
                        ),
                      );
                    }
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
