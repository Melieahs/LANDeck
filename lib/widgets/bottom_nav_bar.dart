import 'package:flutter/material.dart';

class NavDestination {
  const NavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<NavDestination> navDestinations = <NavDestination>[
  NavDestination(icon: Icons.home_outlined, label: '首页'),
  NavDestination(icon: Icons.explore_outlined, label: '发现'),
  NavDestination(icon: Icons.settings_outlined, label: '设置'),
];

/// Material 3 navigation bar shared by the three root tabs.
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
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      destinations: <Widget>[
        for (int index = 0; index < navDestinations.length; index++)
          NavigationDestination(
            key: ValueKey<String>('nav-destination-$index'),
            icon: Icon(navDestinations[index].icon),
            selectedIcon: Icon(
              index == 0
                  ? Icons.home_rounded
                  : index == 1
                  ? Icons.explore_rounded
                  : Icons.settings_rounded,
            ),
            label: navDestinations[index].label,
          ),
      ],
    );
  }
}
