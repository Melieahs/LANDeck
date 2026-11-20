import 'package:material_ui/material_ui.dart';

import '../widgets/bottom_nav_bar.dart';
import 'discover/discover_page.dart';
import 'home/home_page.dart';
import 'settings/settings_page.dart';

/// Root tab container. Each tab keeps its state through an [IndexedStack].
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          for (int i = 0; i < _pages.length; i++)
            TickerMode(
              enabled: i == _currentIndex,
              child: _pages[i],
            ),
        ],
      ),
      bottomNavigationBar: LanDeckNavBar(
        currentIndex: _currentIndex,
        onChanged: _selectTab,
      ),
    );
  }
}
