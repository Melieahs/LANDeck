import 'package:material_ui/material_ui.dart';

import '../../../models/http_credential.dart';

Future<HttpCredential?> showCredentialPicker(
  BuildContext context, {
  required List<HttpCredential> credentials,
}) {
  return showModalBottomSheet<HttpCredential>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '选择要填充的账号',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (int i = 0; i < credentials.length; i++)
              ListTile(
                key: ValueKey<String>('fill-credential-$i'),
                leading: const Icon(Icons.key_rounded),
                title: Text(credentials[i].username),
                subtitle: Text(credentials[i].scopeLabel),
                onTap: () => Navigator.of(context).pop(credentials[i]),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<bool> showSaveWebPasswordDialog(
  BuildContext context, {
  required String serviceName,
  required String host,
  required String username,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        key: const ValueKey<String>('save-web-password-dialog'),
        icon: const Icon(Icons.lock_outline_rounded),
        title: const Text('保存登录信息？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$serviceName · $host'),
            const SizedBox(height: 8),
            Text('用户名：$username'),
            const SizedBox(height: 12),
            Text(
              '密码将使用系统安全存储加密保存在本机，仅用于该服务的密码填充。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('save-web-password-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey<String>('save-web-password-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('加密保存'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
