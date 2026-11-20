import 'package:cupertino_ui/cupertino_ui.dart';

/// iOS visual baseline: system colors, system blue, grouped-list background.
///
/// Brand blue intentionally maps to [CupertinoColors.systemBlue] so the app
/// follows Apple's semantic color in both appearances instead of carrying the
/// Android Material seed into iOS.
abstract final class IosTheme {
  static const Color brandBlue = CupertinoColors.systemBlue;

  static CupertinoThemeData build(Brightness brightness) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: CupertinoColors.systemBlue,
      primaryContrastingColor: CupertinoColors.white,
      barBackgroundColor: CupertinoColors.systemBackground,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    );
  }
}
