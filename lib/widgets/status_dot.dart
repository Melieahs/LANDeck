import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';

/// Small dot used for the real online / offline state.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.isOnline, this.size = 6});

  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = isOnline ? AppColors.online : AppColors.offline;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
