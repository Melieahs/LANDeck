import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Color(0xFF04101F),
      secondary: AppColors.accent,
      onSecondary: Color(0xFF04101F),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
      error: Color(0xFFFF6B7A),
      onError: Color(0xFF1A0507),
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamilyFallback: const <String>[
        'Noto Sans SC',
        'Noto Sans CJK SC',
        'PingFang SC',
        'Microsoft YaHei',
        'sans-serif',
      ],
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.accentSoft,
      highlightColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        actionTextColor: AppColors.accent,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.35,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
