import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  /// Picks the colour scheme from the user's preferences.
  ///
  /// Order of precedence: the system dynamic scheme (Material You), then a
  /// custom seed colour, then the stock LANDeck blue. AMOLED only rewrites the
  /// dark surface roles, so accent colours stay readable.
  static ThemeData schemeFor({
    required Brightness brightness,
    ColorScheme? dynamicScheme,
    Color? seedColor,
    bool amoled = false,
  }) {
    ColorScheme scheme =
        dynamicScheme ??
        (seedColor == null
            ? _brandScheme(brightness)
            : _seededScheme(brightness, seedColor));
    if (amoled && brightness == Brightness.dark) {
      scheme = _amoled(scheme);
    }
    return _build(scheme);
  }

  static const Color brandSeed = Color(0xFF2E6BE6);

  static ThemeData _build(ColorScheme scheme) {
    final Brightness brightness = scheme.brightness;
    final bool isLight = brightness == Brightness.light;
    // Desktop windows already draw their own 44px title bar, so the page app
    // bar shrinks to a compact strip instead of stacking a second 64px row.
    final bool desktopChrome =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Light themes read best as a tinted page with white cards; dark themes
      // keep the page dark and lift the cards one container step, so content
      // floats without any drop shadow. The light page is a touch darker than
      // surfaceContainerLow so white cards separate without borders.
      scaffoldBackgroundColor: isLight ? _lightPage(scheme) : scheme.surface,
      canvasColor: isLight ? _lightPage(scheme) : scheme.surface,
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
        backgroundColor: isLight ? _lightPage(scheme) : scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: desktopChrome ? 48 : 64,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: desktopChrome ? 16 : null,
        ),
      ),
      // Cards are flat tonal containers: white on the tinted light page and
      // one step above the dark page. No elevation shadow, no outline.
      cardTheme: CardTheme(
        color: isLight ? _lightCard(scheme) : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        modalBarrierColor: scheme.scrim.withOpacity(0.42),
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogTheme(
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
          TargetPlatform.android: _FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Material 3 baseline colour scheme generated from the LANDeck seed.
  ///
  /// The official way to derive an M3 palette is a seed colour: Material Theme
  /// Builder and Flutter's [ColorScheme.fromSeed] run the same tonal-palette
  /// algorithm. We do not hand-tune surface roles, so every container step
  /// follows the standard tonal distances.
  static ColorScheme _brandScheme(Brightness brightness) {
    final ColorScheme scheme = _seededScheme(brightness, brandSeed);
    if (brightness == Brightness.light) {
      // The vibrant tonal palette hands back a very dark blue (#0056D2) for
      // filled buttons. On a light page that reads harsh, so the light brand
      // keeps the seed blue itself: 4.8:1 against white text, and visibly
      // softer than the generated primary.
      return scheme.copyWith(
        primary: const Color(0xFF2E6BE6),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFD7E3FF),
        onPrimaryContainer: const Color(0xFF001B3D),
        surfaceTint: const Color(0xFF2E6BE6),
      );
    }
    // Keep the saturated brand accent on the charcoal scale.
    return scheme.copyWith(
      primary: const Color(0xFF4C8DFF),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFF9CBEFF),
      onPrimaryContainer: const Color(0xFF0A2A5C),
      surfaceTint: const Color(0xFF4C8DFF),
    );
  }

  /// A light card tint that follows the accent: white with a whisper of the
  /// primary colour, so a blue theme gets a blue-white card and a green theme
  /// gets a green-white card.
  static Color _lightCard(ColorScheme scheme) =>
      Color.alphaBlend(scheme.primary.withOpacity(0.12), Colors.white);

  /// Slightly deepened page tint: white cards get a little more separation
  /// than the raw surfaceContainerLow without turning the page grey.
  static Color _lightPage(ColorScheme scheme) => Color.alphaBlend(
    scheme.onSurface.withOpacity(0.09),
    scheme.surfaceContainerLow,
  );

  static ColorScheme _seededScheme(Brightness brightness, Color seed) {
    final ColorScheme base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      // "Vibrant" is one of the official Material Theme Builder variants and
      // keeps the LANDeck blue recognisable instead of the muted tonal-spot
      // primary.
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    if (brightness == Brightness.light) {
      // The vibrant palette generates a very dark primary (#0056D2 for the
      // brand blue). That reads harsh as a filled button on a light page, so
      // every palette uses its seed colour directly; black or white text is
      // picked by luminance so light seeds (amber, lime) stay readable.
      final bool darkText = seed.computeLuminance() > 0.179;
      return base.copyWith(
        primary: seed,
        onPrimary: darkText ? const Color(0xFF1B1B1F) : const Color(0xFFFFFFFF),
        surfaceTint: seed,
      );
    }
    // Dark mode follows the neutral charcoal scale used by the Windows
    // reference: a near-black page, cards one step lighter. Surface roles are
    // pinned to neutral greys while the accent stays derived from the seed.
    final Color container = Color.lerp(base.primary, Colors.white, 0.38)!;
    final Color onContainer = Color.lerp(base.primary, Colors.black, 0.55)!;
    return base.copyWith(
      primaryContainer: container,
      onPrimaryContainer: onContainer,
      secondaryContainer: Color.lerp(base.secondary, Colors.white, 0.34)!,
      onSecondaryContainer: Color.lerp(base.secondary, Colors.black, 0.5)!,
      tertiaryContainer: Color.lerp(base.tertiary, Colors.white, 0.34)!,
      onTertiaryContainer: Color.lerp(base.tertiary, Colors.black, 0.5)!,
      surface: const Color(0xFF1B1B1D),
      surfaceContainerLowest: const Color(0xFF141416),
      surfaceContainerLow: const Color(0xFF262628),
      surfaceContainer: const Color(0xFF2A2A2C),
      surfaceContainerHigh: const Color(0xFF303032),
      surfaceContainerHighest: const Color(0xFF353537),
      onSurface: const Color(0xFFF2F2F3),
      onSurfaceVariant: const Color(0xFFB4B4B8),
      outline: const Color(0xFF6A6A70),
      outlineVariant: const Color(0xFF353538),
      inverseSurface: const Color(0xFFEAEAEC),
    );
  }

  static ColorScheme _amoled(ColorScheme scheme) => scheme.copyWith(
    surface: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0C0C0E),
    surfaceContainer: const Color(0xFF101012),
    surfaceContainerHigh: const Color(0xFF161618),
    surfaceContainerHighest: const Color(0xFF1C1C1E),
    onSurface: const Color(0xFFF2F2F3),
    onSurfaceVariant: const Color(0xFFB4B4B8),
    outline: const Color(0xFF6A6A70),
    outlineVariant: const Color(0xFF2A2A2D),
  );
}

/// Flutter 3.27 added [FadeForwardsPageTransitionsBuilder]; this keeps the
/// same fade-through-slide feel on the 3.24 SDK used by the Catalina build.
class _FadeForwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final CurvedAnimation curve = CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
