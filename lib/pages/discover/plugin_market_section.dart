import 'package:flutter/material.dart';

import '../../core/utils/feedback.dart';
import '../../native/native_module_registry.dart';
import '../../native/plugin/imported_module_store.dart';
import '../../native/plugin/plugin_catalog.dart';
import '../../native/plugin/plugin_install_dialog.dart';
import '../../native/plugin/plugin_manifest.dart';
import '../../widgets/list_skeleton.dart';

/// Lists declarative plugins published in the LANDeck repository and installs
/// them after an explicit confirmation.
class PluginMarketSection extends StatefulWidget {
  const PluginMarketSection({super.key, this.catalog, this.store});

  final PluginCatalog? catalog;
  final ImportedPluginStore? store;

  @override
  State<PluginMarketSection> createState() => _PluginMarketSectionState();
}

class _PluginMarketSectionState extends State<PluginMarketSection> {
  PluginCatalog get _catalog => widget.catalog ?? PluginCatalog.instance;

  ImportedPluginStore get _store =>
      widget.store ?? ImportedPluginStore.instance;

  bool _loading = true;
  String? _error;
  List<PluginCatalogEntry> _entries = const <PluginCatalogEntry>[];
  String? _installingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<PluginCatalogEntry> entries = await _catalog.fetch();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _install(PluginCatalogEntry entry) async {
    if (_installingId != null) {
      return;
    }
    setState(() => _installingId = entry.id);
    try {
      final ImportedNativeModule module = await _catalog.download(entry);
      if (!mounted) {
        return;
      }
      final bool confirmed = await confirmPluginInstall(
        context,
        module,
        title: '安装原生模块？',
        confirmLabel: '安装',
      );
      if (!confirmed || !mounted) {
        return;
      }
      final ImportedPluginResult result = await _store.install(module);
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        result.replaced ? '已更新模块「${module.name}」' : '已安装模块「${module.name}」',
      );
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, '安装失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _installingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('模块插件', style: theme.textTheme.titleMedium),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    key: const ValueKey<String>('refresh-plugin-catalog'),
                    tooltip: '刷新插件源',
                    visualDensity: VisualDensity.compact,
                    onPressed: _installingId == null ? _load : null,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '从 LANDeck 仓库直接安装声明式原生模块，插件不执行代码',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ..._content(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(ThemeData theme) {
    final String? error = _error;
    if (error != null) {
      return <Widget>[
        Text(
          error,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>('retry-plugin-catalog'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重试'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _catalog.indexUri.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ];
    }
    if (_loading) {
      return <Widget>[
        const ListSkeleton(rows: 2, rowHeight: 52, padding: EdgeInsets.zero),
      ];
    }
    if (_entries.isEmpty) {
      return <Widget>[
        Text(
          '插件源暂无可用插件',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    return <Widget>[
      for (int i = 0; i < _entries.length; i++) ...<Widget>[
        if (i != 0) const Divider(height: 1),
        _entryTile(theme, _entries[i]),
      ],
    ];
  }

  Widget _entryTile(ThemeData theme, PluginCatalogEntry entry) {
    final bool installed = NativeModuleRegistry.instance.byId(entry.id) != null;
    final bool installing = _installingId == entry.id;
    return ListTile(
      key: ValueKey<String>('catalog-plugin-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.extension_outlined),
      title: Row(
        children: <Widget>[
          Flexible(child: Text(entry.name)),
          const SizedBox(width: 6),
          Text(
            'v${entry.version}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Text(
        entry.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: installed
          ? const Chip(
              label: Text('已安装'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : installing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              key: ValueKey<String>('install-plugin-${entry.id}'),
              onPressed: _installingId == null ? () => _install(entry) : null,
              child: const Text('安装'),
            ),
    );
  }
}
