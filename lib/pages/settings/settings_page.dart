import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/feedback.dart';
import '../../repositories/service_repository.dart';
import '../devices/devices_page.dart';
import '../downloads/downloads_page.dart';
import '../../native/native_module_registry.dart';
import 'appearance_page.dart';
import 'native_modules_page.dart';
import 'storage_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onOpenDiscover});

  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final ThemeController themeController = ThemeScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSettingsPageMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Text('设置', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              const _SectionLabel('外观'),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const ValueKey<String>('appearance-entry'),
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('主题'),
                  subtitle: Text(_themeSummary(themeController)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const AppearancePage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('设备与网络'),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.devices_other_outlined),
                      title: const Text('设备管理'),
                      subtitle: Text('${repository.devices.length} 台设备'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const DevicesPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.wifi_tethering_rounded),
                      title: const Text('局域网扫描'),
                      subtitle: const Text('在「发现」中扫描当前 Wi-Fi 网段'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: onOpenDiscover,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const _SectionLabel('原生模块'),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.extension_rounded),
                  title: const Text('原生模块'),
                  subtitle: Text(
                    '已安装 ${NativeModuleRegistry.instance.installed.length} 个模块',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          const NativeModulesPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('数据'),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('数据存储'),
                      subtitle: Text(
                        '${repository.services.length} 个服务 · '
                        '${repository.devices.length} 台设备',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const StoragePage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: const Text('下载管理'),
                      subtitle: Text(
                        repository.activeDownloadCount > 0
                            ? '${repository.activeDownloadCount} 个任务进行中'
                            : '查看下载任务与已保存文件',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              const DownloadsPage(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: const Text('隐私'),
                      subtitle: const Text('扫描只访问当前局域网，不读取位置。'),
                      onTap: () =>
                          showAppSnackBar(context, '不启用账号，不上传数据，不扫描公网。'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('关于'),
              Card.outlined(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('LANDeck'),
                  subtitle: const Text('v0.9.3 · 模块插件 · 本地优先'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'LANDeck',
                    applicationVersion: '0.9.3',
                    applicationLegalese: 'Local-first. No account. No cloud.',
                    children: const <Widget>[
                      SizedBox(height: 12),
                      Text(
                        '集中管理家中的 NAS、路由器、电脑与 Docker 服务。'
                        '所有数据保存在本机。',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'LANDeck · Local-first',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

String _themeSummary(ThemeController controller) {
  final String mode = switch (controller.mode) {
    ThemeMode.system => '跟随系统',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };
  final String palette = controller.dynamicColor
      ? '动态取色'
      : controller.seedColor == null
      ? 'LANDeck 蓝'
      : '自定义配色';
  return '$mode · $palette';
}
