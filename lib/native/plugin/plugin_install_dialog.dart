import 'package:flutter/material.dart';

import 'plugin_manifest.dart';

/// Shows what a declarative plugin may request and returns true when the user
/// confirms installation.
Future<bool> confirmPluginInstall(
  BuildContext context,
  ImportedNativeModule module, {
  String title = '导入原生模块？',
  String confirmLabel = '导入',
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.extension_rounded),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${module.name} · v${module.version}'),
            const SizedBox(height: 6),
            Text(module.description),
            if (module.manifest.author != null) ...<Widget>[
              const SizedBox(height: 6),
              Text('作者：${module.manifest.author}'),
            ],
            const SizedBox(height: 12),
            Text(
              '此插件只包含声明式 HTTP 配置，不会执行第三方代码。'
              '它可以向关联服务的地址发送以下请求，请只导入可信来源：',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              <String>[
                if (module.manifest.actions.isNotEmpty)
                  '操作：${module.manifest.actions.map((PluginAction item) => item.label).join('、')}',
                if (module.manifest.status != null)
                  '状态读取：${module.manifest.status!.method} ${module.manifest.status!.path}',
              ].join('；'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey<String>('confirm-plugin-install'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
