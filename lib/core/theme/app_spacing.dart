import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppSpacing {
  static const double page = 20;
  static const double sectionGap = 26;
}

/// Layout widths for the phone-first canvas used on wide displays and on the
/// web preview.
const double kMaxAppWidth = 520;

BoxDecoration appCardDecoration({Color? color, Color? borderColor}) {
  return BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? AppColors.border),
  );
}
