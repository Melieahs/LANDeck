import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(icon: Icons.home_rounded, label: '首页'),
  NavDestination(icon: Icons.explore_rounded, label: '发现'),
  NavDestination(icon: Icons.settings_rounded, label: '设置'),
];

class LanDeckNavBar extends StatelessWidget {
  const LanDeckNavBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
              child: Row(
                children: <Widget>[
                  for (int index = 0; index < navDestinations.length; index++)
                    Expanded(
                      key: ValueKey<String>('nav-destination-$index'),
                      child: _NavItem(
                        destination: navDestinations[index],
                        selected: index == currentIndex,
                        onTap: () => onChanged(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? AppColors.accent : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 42,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? AppColors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(destination.icon, size: 19, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
