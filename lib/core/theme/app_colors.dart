import 'package:material_ui/material_ui.dart';

/// LANDeck semantic colours.
///
/// Material 3 components read colours from [ColorScheme]. A small number of
/// legacy surfaces still use these named colours, so the palette follows the
/// effective [Brightness] and is refreshed by [LanDeckApp] whenever the theme
/// changes. Prefer `Theme.of(context).colorScheme` in new widgets.
abstract final class AppColors {
  static Brightness _brightness = Brightness.dark;

  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get isLight => _brightness == Brightness.light;

  static Color get background =>
      isLight ? const Color(0xFFF8F9FF) : const Color(0xFF0B0F14);

  static Color get surface =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0xFF151A21);

  static Color get surfaceHigh =>
      isLight ? const Color(0xFFECF0F7) : const Color(0xFF20262F);

  static Color get surfaceSoft =>
      isLight ? const Color(0xFFF1F4FA) : const Color(0xFF10151B);

  static Color get border =>
      isLight ? const Color(0xFFD8E0EC) : const Color(0xFF2A3341);

  static Color get accent =>
      isLight ? const Color(0xFF1B5FD9) : const Color(0xFFAAC7FF);

  static Color get accentSoft => isLight
      ? const Color(0x1A1B5FD9)
      : const Color(0x33AAC7FF);

  static Color get textPrimary =>
      isLight ? const Color(0xFF171C24) : const Color(0xFFE3E8F0);

  static Color get textSecondary =>
      isLight ? const Color(0xFF4B5565) : const Color(0xFFAAB6C8);

  static Color get textMuted =>
      isLight ? const Color(0xFF77808F) : const Color(0xFF7C8899);

  static Color get online =>
      isLight ? const Color(0xFF146C43) : const Color(0xFF6EDBA8);

  static Color get offline =>
      isLight ? const Color(0xFF8A93A2) : const Color(0xFF8A96A6);

  static Color get error =>
      isLight ? const Color(0xFFBA1A1A) : const Color(0xFFFFB4AB);
}
