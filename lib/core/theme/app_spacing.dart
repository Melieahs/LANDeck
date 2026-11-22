import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppSpacing {
  static const double page = 20;
  static const double sectionGap = 26;
}

/// Layout widths for the phone-first canvas used on wide displays and on the
/// web preview.
///
/// Pages pick a width by content type: browsing lists read best wide, settings
/// stay narrower, and single-column forms narrowest of all. On phones every
/// page falls back to [kMaxAppWidth].
const double kMaxAppWidth = 520;

/// Browsing surfaces: service, device and discovery lists.
const double kListPageMaxWidth = 840;

/// Grouped settings surfaces.
const double kSettingsPageMaxWidth = 720;

/// Single-column editor forms.
const double kFormPageMaxWidth = 640;

BoxDecoration appCardDecoration({Color? color, Color? borderColor}) {
  return BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? AppColors.border),
  );
}
