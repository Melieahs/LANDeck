import 'package:material_ui/material_ui.dart';

/// Width-based layout rules shared by the phone-first Material UI.
///
/// The side navigation appears on tablets: iPads in portrait start at 744 pt,
/// while even the widest iPhones stay below 500 pt in their shortest side, so
/// a landscape phone keeps the compact layout. The 800×600 test surface also
/// stays compact because the shortest side must be *greater* than 600.
abstract final class AdaptiveLayout {
  static const double sideNavigationMinWidth = 700;
  static const double tabletMinShortestSide = 600;

  /// The expanded navigation rail on the left of the tablet layout.
  static const double railWidth = 232;

  /// Home content may use the extra width on a tablet.
  static const double wideHomeMaxWidth = 1160;

  static bool usesSideNavigation(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return size.width >= sideNavigationMinWidth &&
        size.shortestSide > tabletMinShortestSide;
  }
}
