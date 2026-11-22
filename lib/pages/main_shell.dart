import 'package:material_ui/material_ui.dart';

import '../core/ui/adaptive_layout.dart';
import '../widgets/bottom_nav_bar.dart';
import 'discover/discover_page.dart';
import 'home/home_page.dart';
import 'settings/settings_page.dart';

/// Root tab container. Each tab keeps its state through an [IndexedStack].
///
/// Phones use the Material 3 bottom navigation bar; tablets switch to a
/// persistent navigation rail so the content can use the full width.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomePage(
        onOpenSettings: () => _selectTab(2),
        onOpenDiscover: () => _selectTab(1),
      ),
      const DiscoverPage(),
      SettingsPage(onOpenDiscover: () => _selectTab(1)),
    ];
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() => _currentIndex = index);
  }

  Widget _content() {
    return IndexedStack(
      index: _currentIndex,
      children: <Widget>[
        for (int i = 0; i < _pages.length; i++)
          TickerMode(enabled: i == _currentIndex, child: _pages[i]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool sideNavigation = AdaptiveLayout.usesSideNavigation(context);

    if (!sideNavigation) {
      return Scaffold(
        body: _content(),
        bottomNavigationBar: LanDeckNavBar(
          currentIndex: _currentIndex,
          onChanged: _selectTab,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        right: false,
        child: Row(
          children: <Widget>[
            _MainRail(
              currentIndex: _currentIndex,
              onChanged: _selectTab,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }
}

class _MainRail extends StatelessWidget {
  const _MainRail({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return NavigationRail(
      key: const ValueKey<String>('main-navigation-rail'),
      extended: true,
      minExtendedWidth: AdaptiveLayout.railWidth,
      groupAlignment: -1,
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.router_outlined,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'LANDeck',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      destinations: <NavigationRailDestination>[
        for (int index = 0; index < navDestinations.length; index++)
          NavigationRailDestination(
            icon: Icon(navDestinations[index].icon),
            selectedIcon: Icon(
              index == 0
                  ? Icons.home_rounded
                  : index == 1
                  ? Icons.explore_rounded
                  : Icons.settings_rounded,
            ),
            label: Text(navDestinations[index].label),
          ),
      ],
    );
  }
}
