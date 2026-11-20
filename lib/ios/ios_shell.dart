import 'package:cupertino_ui/cupertino_ui.dart';

import 'glass/ios_glass_tab_bar.dart';
import 'pages/ios_discover_page.dart';
import 'pages/ios_home_page.dart';
import 'pages/ios_settings_page.dart';

/// iOS root: content pages with a floating native Liquid Glass tab bar.
class IosShell extends StatefulWidget {
  const IosShell({super.key});

  @override
  State<IosShell> createState() => _IosShellState();
}

class _IosShellState extends State<IosShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: switch (_index) {
              0 => const IosHomePage(),
              1 => const IosDiscoverPage(),
              _ => const IosSettingsPage(),
            },
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 6,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: IosGlassTabBar(
                  selectedIndex: _index,
                  onSelected: (int index) => setState(() => _index = index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
