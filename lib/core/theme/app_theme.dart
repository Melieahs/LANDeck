import 'package:material_ui/material_ui.dart';

/// Material 3 theme for LANDeck.
///
/// One seed colour drives both schemes, while surfaces and status colours stay
/// intentionally restrained. All pages, dialogs, sheets and form controls read
/// from this theme so light, dark and system modes remain consistent.
abstract final class AppTheme {
  static ThemeData get light => lightWith(null);

  static ThemeData get dark => darkWith(null);

  /// Builds the brand theme, or applies a system dynamic [scheme] when given.
  static ThemeData lightWith(ColorScheme? scheme) =>
      _build(scheme ?? _brandScheme(Brightness.light));

  static ThemeData darkWith(ColorScheme? scheme) =>
      _build(scheme ?? _brandScheme(Brightness.dark));

  static ThemeData _build(ColorScheme scheme) {
    final Brightness brightness = scheme.brightness;
    final bool isLight = brightness == Brightness.light;
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const <String>[
        'Noto Sans SC',
        'Noto Sans CJK SC',
        'PingFang SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
    );

    final TextTheme textTheme = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: isLight ? scheme.surfaceContainerLow : scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        modalBarrierColor: scheme.scrim.withValues(alpha: 0.42),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          fontSize: 22,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontSize: 13,
        ),
        actionTextColor: scheme.inversePrimary,
        elevation: 2,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 1,
        focusElevation: 2,
        hoverElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ColorScheme _brandScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E6BE6),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF1B5FD9),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFD8E2FF),
        onPrimaryContainer: const Color(0xFF001A41),
        secondary: const Color(0xFF50606F),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFD3E4F6),
        onSecondaryContainer: const Color(0xFF0B1D2A),
        surface: const Color(0xFFF8F9FF),
        onSurface: const Color(0xFF171C24),
        onSurfaceVariant: const Color(0xFF4B5565),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFFFFFF),
        surfaceContainer: const Color(0xFFEEF1F8),
        surfaceContainerHigh: const Color(0xFFE7EBF3),
        surfaceContainerHighest: const Color(0xFFE0E5EE),
        outline: const Color(0xFF73777F),
        outlineVariant: const Color(0xFFD8E0EC),
        error: const Color(0xFFBA1A1A),
        onError: Colors.white,
        inverseSurface: const Color(0xFF2D3138),
        onInverseSurface: const Color(0xFFF1F3F8),
        inversePrimary: const Color(0xFFAAC7FF),
        scrim: Colors.black,
      );
    }
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6BE6),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFAAC7FF),
      onPrimary: const Color(0xFF002F65),
      primaryContainer: const Color(0xFF17457F),
      onPrimaryContainer: const Color(0xFFD7E3FF),
      secondary: const Color(0xFFBCC7DC),
      onSecondary: const Color(0xFF263141),
      secondaryContainer: const Color(0xFF3C4858),
      onSecondaryContainer: const Color(0xFFD7E3F8),
      surface: const Color(0xFF0B0F14),
      onSurface: const Color(0xFFE3E8F0),
      onSurfaceVariant: const Color(0xFFAAB6C8),
      surfaceContainerLowest: const Color(0xFF070A0E),
      surfaceContainerLow: const Color(0xFF12171E),
      surfaceContainer: const Color(0xFF171D25),
      surfaceContainerHigh: const Color(0xFF212832),
      surfaceContainerHighest: const Color(0xFF2A323D),
      outline: const Color(0xFF8C9199),
      outlineVariant: const Color(0xFF2A3341),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      inverseSurface: const Color(0xFFE3E8F0),
      onInverseSurface: const Color(0xFF2A313A),
      inversePrimary: const Color(0xFF1B5FD9),
      scrim: Colors.black,
    );
  }
}
