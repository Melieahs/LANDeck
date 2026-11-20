import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/device_categories.dart';
import '../../../models/device_category.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';

class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.counts,
    required this.onSelect,
  });

  final Map<DeviceCategory, int> counts;
  final ValueChanged<DeviceCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '设备分类', trailing: '轻点筛选'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: homeCategories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 100,
          ),
          itemBuilder: (BuildContext context, int index) {
            final DeviceCategory category = homeCategories[index];
            return _CategoryCard(
              category: category,
              count: counts[category] ?? 0,
              highlighted: category == DeviceCategory.all,
              onTap: () => onSelect(category),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.highlighted,
    required this.onTap,
  });

  final DeviceCategory category;
  final int count;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFF14223A) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted
              ? AppColors.accent.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppColors.accent.withValues(alpha: 0.16)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  iconForCategory(category),
                  size: 19,
                  color: highlighted ? AppColors.accent : const Color(0xFF9DB7E4),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count 个',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
