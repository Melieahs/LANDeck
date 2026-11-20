import 'package:cupertino_ui/cupertino_ui.dart';

import '../../core/app_scope.dart';
import 'ios_device_editor_page.dart';

class IosDiscoverPage extends StatelessWidget {
  const IosDiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final int deviceCount = AppScope.of(context).devices.length;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          const CupertinoSliverNavigationBar(
            largeTitle: Text('发现'),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                CupertinoListSection.insetGrouped(
                  header: const Text('局域网发现'),
                  footer: const Text(
                    'iOS 上的自动发现将使用 Bonjour 和多播，并受系统「本地网络」权限控制。'
                    '当前阶段只展示真实的本地入口，不生成模拟设备或服务。',
                  ),
                  children: <Widget>[
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.antenna_radiowaves_left_right),
                      title: const Text('扫描局域网设备'),
                      subtitle: const Text('接入 Bonjour / SSDP 后开放'),
                      additionalInfo: const Text('阶段 E'),
                      onTap: () => _showPhaseAlert(
                        context,
                        '设备发现将在阶段 E 接入',
                        '将使用 Bonjour、SSDP 和当前子网主机发现，结果只作为候选设备，确认后才会写入数据库。',
                      ),
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.wifi),
                      title: const Text('扫描设备服务端口'),
                      subtitle: const Text('从设备详情页发起'),
                      additionalInfo: const Text('阶段 E'),
                      onTap: () => _showPhaseAlert(
                        context,
                        '端口扫描将在阶段 E 接入',
                        '只扫描已保存设备的地址，不会扫描整个局域网；开放端口需要用户确认后才添加为服务。',
                      ),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('已有设备'),
                  children: <Widget>[
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.archivebox),
                      title: const Text('设备管理'),
                      additionalInfo: Text('$deviceCount 台'),
                      subtitle: const Text('可以先手动添加设备，再在设备详情里添加服务'),
                    ),
                    CupertinoListTile(
                      leading: const Icon(CupertinoIcons.add),
                      title: const Text('手动添加设备'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (BuildContext context) =>
                                const IosDeviceEditorPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Text(
                    '局域网权限：首次发现设备时，iOS 会询问是否允许 LANDeck 访问本地网络。'
                    '拒绝后需要在系统设置中重新开启。',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhaseAlert(
    BuildContext context,
    String title,
    String message,
  ) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
