import 'package:cupertino_ui/cupertino_ui.dart';

import 'pages/ios_discover_page.dart';
import 'pages/ios_home_page.dart';
import 'pages/ios_settings_page.dart';

/// iOS root: native tab bar, one navigation stack per tab.
class IosShell extends StatelessWidget {
  const IosShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: CupertinoTheme.of(context).primaryColor,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.antenna_radiowaves_left_right),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        return CupertinoTabView(
          builder: (BuildContext context) => switch (index) {
            0 => const IosHomePage(),
            1 => const IosDiscoverPage(),
            _ => const IosSettingsPage(),
          },
        );
      },
    );
  }
}
