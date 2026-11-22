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

    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool compactRail = AdaptiveLayout.usesCompactRail(context);

    return Scaffold(
      // The rail background runs edge to edge like a desktop sidebar; only
      // its contents respect the safe area.
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: compactRail
                ? AdaptiveLayout.compactRailWidth
                : AdaptiveLayout.railWidth,
            color: colors.surfaceContainerLow,
            child: SafeArea(
              right: false,
              bottom: false,
              child: _MainRail(
                compact: compactRail,
                currentIndex: _currentIndex,
                onChanged: _selectTab,
              ),
            ),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }
}

class _MainRail extends StatelessWidget {
  const _MainRail({
    required this.compact,
    required this.currentIndex,
    required this.onChanged,
  });

  final bool compact;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    final Widget brand = Container(
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
    );

    return NavigationRail(
      key: const ValueKey<String>('main-navigation-rail'),
      extended: !compact,
      minExtendedWidth: compact ? null : AdaptiveLayout.railWidth,
      minWidth: compact ? AdaptiveLayout.compactRailWidth : null,
      labelType: compact ? NavigationRailLabelType.all : null,
      backgroundColor: Colors.transparent,
      groupAlignment: -1,
      selectedIndex: currentIndex,
      onDestinationSelected: onChanged,
      leading: Padding(
        padding: compact
            ? const EdgeInsets.only(top: 20, bottom: 20)
            : const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: compact
            ? brand
            : Row(
                children: <Widget>[
                  brand,
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
