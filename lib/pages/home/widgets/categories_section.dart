import 'package:material_ui/material_ui.dart';

import '../../../data/device_categories.dart';
import '../../../models/device_category.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/service_icon.dart';

/// Category shortcuts. Material 3 chips keep the section light instead of
/// stacking another grid of cards on the home page.
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
        const SectionHeader(title: '设备分类', trailing: '按类型筛选'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final DeviceCategory category in homeCategories)
              ActionChip(
                key: ValueKey<String>('category-chip-${category.name}'),
                avatar: Icon(iconForCategory(category), size: 18),
                label: Text('${category.label}  ${counts[category] ?? 0}'),
                onPressed: () => onSelect(category),
              ),
          ],
        ),
      ],
    );
  }
}
