import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Width-based layout rules shared by the phone-first Material UI.
///
/// Tablets get the extended navigation rail and a two-column home. Desktop
/// windows (Windows/macOS/Linux) get a narrower icon rail and use the full
/// window width for content. Phones keep the bottom navigation.
abstract final class AdaptiveLayout {
  static const double sideNavigationMinWidth = 700;
  static const double tabletMinShortestSide = 600;

  /// The expanded navigation rail on the left of the tablet layout.
  static const double railWidth = 256;

  /// The narrow icon rail used by desktop windows.
  static const double compactRailWidth = 80;

  /// Home content may use the extra width on a tablet or a desktop window.
  static const double wideHomeMaxWidth = 1160;

  /// Below this window width the desktop home falls back to one column so
  /// the two-column layout never squeezes.
  static const double wideHomeMinWidth = 860;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Desktop windows always use the narrow rail; there is no bottom bar.
  static bool usesCompactRail(BuildContext context) => isDesktop;

  static bool usesSideNavigation(BuildContext context) {
    if (usesCompactRail(context)) {
      return true;
    }
    final Size size = MediaQuery.sizeOf(context);
    return size.width >= sideNavigationMinWidth &&
        size.shortestSide > tabletMinShortestSide;
  }

  static bool usesWideHome(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    if (usesCompactRail(context)) {
      return size.width >= wideHomeMinWidth;
    }
    return size.width >= sideNavigationMinWidth &&
        size.shortestSide > tabletMinShortestSide;
  }
}
