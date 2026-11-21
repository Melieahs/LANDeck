import 'package:material_ui/material_ui.dart';

import '../../native/native_module.dart';
import '../../native/native_module_registry.dart';

/// Read-only list of installed native modules.
///
/// Installation and dynamic loading are intentionally out of scope; the page
/// makes the current capability explicit instead of inventing modules.
class NativeModulesPage extends StatelessWidget {
  const NativeModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<NativeModule> modules = NativeModuleRegistry.instance.installed;
    return Scaffold(
      appBar: AppBar(title: const Text('原生模块')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          Text(
            '原生模块为服务提供 Flutter 原生控制界面，与 WebView 共用同一条服务记录。'
            '安装、签名与动态加载第三方模块暂未开放。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (modules.isEmpty)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.extension_off_rounded,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text('尚未安装原生模块'),
                    const SizedBox(height: 6),
                    Text(
                      '所有服务继续使用 Web 模式。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card.outlined(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < modules.length; i++) ...<Widget>[
                    ListTile(
                      key: ValueKey<String>('native-module-${modules[i].id}'),
                      leading: const Icon(Icons.extension_rounded),
                      title: Text(modules[i].name),
                      subtitle: Text(
                        'v${modules[i].version} · ${modules[i].description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i != modules.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
