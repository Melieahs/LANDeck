import 'package:material_ui/material_ui.dart';

/// Central palette for LANDeck.
///
/// The visual direction is a deep blue-black, local-first dark UI with a
/// single blue accent, blue-grey surfaces and status colours reserved for
/// online / offline meaning only.
abstract final class AppColors {
  static const Color background = Color(0xFF070B14);
  static const Color surface = Color(0xFF111A2B);
  static const Color surfaceHigh = Color(0xFF18233A);
  static const Color surfaceSoft = Color(0xFF0C1424);
  static const Color border = Color(0xFF1F2C45);

  static const Color accent = Color(0xFF5B9BFF);
  static const Color accentSoft = Color(0x1F5B9BFF);

  static const Color textPrimary = Color(0xFFF1F5FF);
  static const Color textSecondary = Color(0xFF93A3BE);
  static const Color textMuted = Color(0xFF5E708C);

  static const Color online = Color(0xFF3AD59B);
  static const Color offline = Color(0xFF5F6D85);
}
