import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/feedback.dart';
import '../../native/native_module.dart';
import '../../native/native_module_registry.dart';
import '../../native/plugin/imported_module_store.dart';
import '../../native/plugin/plugin_install_dialog.dart';
import '../../native/plugin/plugin_manifest.dart';

/// Lists built-in and imported native modules.
class NativeModulesPage extends StatefulWidget {
  const NativeModulesPage({super.key});

  @override
  State<NativeModulesPage> createState() => _NativeModulesPageState();
}

class _NativeModulesPageState extends State<NativeModulesPage> {
  bool _busy = false;

  List<NativeModule> get _modules => NativeModuleRegistry.instance.installed;

  Future<void> _import() async {
    if (_busy) {
      return;
    }
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: '选择模块插件（.json / .zip）',
        type: FileType.any,
      );
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, '无法打开文件选择器：$error');
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final ImportedNativeModule module = await ImportedPluginStore.instance
          .previewBytes(
            await picked.xFile.readAsBytes(),
            fileName: picked.name,
          );
      if (!mounted) {
        return;
      }
      final bool confirmed = await confirmPluginInstall(context, module);
      if (!confirmed) {
        return;
      }
      final ImportedPluginResult result = await ImportedPluginStore.instance
          .install(module);
      if (!mounted) {
        return;
      }
      setState(() {});
      showAppSnackBar(
        context,
        result.replaced ? '已更新模块「${module.name}」' : '已导入模块「${module.name}」',
      );
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, '导入失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(ImportedNativeModule module) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('移除「${module.name}」？'),
        content: const Text('已关联此模块的服务会回退为 Web 模式；已保存的密码不会被删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ImportedPluginStore.instance.delete(module.id);
    if (mounted) {
      setState(() {});
      showAppSnackBar(context, '已移除模块「${module.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<NativeModule> modules = _modules;
    return Scaffold(
      appBar: AppBar(
        title: const Text('原生模块'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('import-native-module'),
            tooltip: '导入模块',
            onPressed: _busy ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          Text(
            '原生模块为服务提供 Flutter 原生控制界面，与 WebView 共用同一条服务记录。'
            '可导入声明式插件；插件不执行代码，只能访问关联服务。',
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
                      leading: Icon(
                        modules[i].isBuiltin
                            ? Icons.extension_rounded
                            : Icons.extension_outlined,
                      ),
                      title: Text(modules[i].name),
                      subtitle: Text(
                        'v${modules[i].version} · ${modules[i].description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: modules[i].isBuiltin
                          ? Chip(
                              label: const Text('内置'),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            )
                          : IconButton(
                              key: ValueKey<String>(
                                'delete-native-module-${modules[i].id}',
                              ),
                              tooltip: '移除',
                              onPressed: () =>
                                  _delete(modules[i] as ImportedNativeModule),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                    ),
                    if (i != modules.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('导入 .json / .zip 插件'),
          ),
          const SizedBox(height: 12),
          Text(
            '插件格式说明见项目 docs/native-modules.md。导入前会显示模块声明的请求，'
            '由你确认后才安装。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
