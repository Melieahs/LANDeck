import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../../core/app_scope.dart';
import '../../core/theme/theme_controller.dart';

class IosSettingsPage extends StatelessWidget {
  const IosSettingsPage({super.key});

  String _modeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
  }

  Future<void> _pickTheme(BuildContext context) async {
    final ThemeController controller = ThemeScope.of(context);
    final ThemeMode? selected = await showCupertinoModalPopup<ThemeMode>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('外观'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ThemeMode.system),
            child: const Text('跟随系统'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ThemeMode.light),
            child: const Text('浅色'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ThemeMode.dark),
            child: const Text('深色'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected != null) {
      await controller.setMode(selected);
    }
  }

  Future<void> _showAbout(BuildContext context) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('关于 LANDeck'),
        content: const Text(
          'LANDeck\n本地优先的局域网服务启动器。\n\n数据只保存在本机，不经过云端。\n版本 0.7.4 (iOS Phase B)',
        ),
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

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final int deviceCount = AppScope.of(context).devices.length;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          const CupertinoSliverNavigationBar(
            largeTitle: Text('设置'),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                CupertinoListSection.insetGrouped(
                  header: const Text('外观'),
                  children: <Widget>[
                    CupertinoListTile(
                      key: const ValueKey<String>('ios-theme-row'),
                      title: const Text('外观'),
                      additionalInfo: Text(_modeLabel(controller.mode)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _pickTheme(context),
                    ),
                    const CupertinoListTile(
                      title: Text('颜色'),
                      subtitle: Text('iOS 系统语义色与系统蓝，自动适配浅色和深色'),
                      additionalInfo: Text('自动'),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('局域网'),
                  footer: const Text('设备发现与端口扫描将在后续阶段使用 iOS 原生网络能力实现。'),
                  children: <Widget>[
                    CupertinoListTile(
                      title: const Text('已保存设备'),
                      leading: const Icon(CupertinoIcons.archivebox),
                      additionalInfo: Text('$deviceCount 台'),
                    ),
                    const CupertinoListTile(
                      title: Text('自动发现设备'),
                      leading: Icon(CupertinoIcons.antenna_radiowaves_left_right),
                      additionalInfo: Text('阶段 E'),
                    ),
                    const CupertinoListTile(
                      title: Text('服务端口扫描'),
                      leading: Icon(CupertinoIcons.wifi),
                      additionalInfo: Text('阶段 E'),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('数据'),
                  children: <Widget>[
                    CupertinoListTile(
                      title: Text('下载管理'),
                      leading: Icon(CupertinoIcons.tray_arrow_down),
                      additionalInfo: Text('阶段 D'),
                    ),
                    CupertinoListTile(
                      title: Text('数据存储'),
                      leading: Icon(CupertinoIcons.folder),
                      additionalInfo: Text('仅本机'),
                    ),
                    CupertinoListTile(
                      title: Text('账号与云同步'),
                      leading: Icon(CupertinoIcons.cloud),
                      additionalInfo: Text('不启用'),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: const Text('关于'),
                  children: <Widget>[
                    CupertinoListTile(
                      title: const Text('关于 LANDeck'),
                      leading: const Icon(CupertinoIcons.info_circle),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showAbout(context),
                    ),
                    const CupertinoListTile(
                      title: Text('版本'),
                      additionalInfo: Text('0.7.4 (iOS Phase B)'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
