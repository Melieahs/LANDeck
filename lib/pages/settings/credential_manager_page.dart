import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_skeleton.dart';

class CredentialManagerPage extends StatefulWidget {
  const CredentialManagerPage({super.key});

  @override
  State<CredentialManagerPage> createState() => _CredentialManagerPageState();
}

class _CredentialManagerPageState extends State<CredentialManagerPage> {
  final HttpCredentialStore _store = HttpCredentialStore.instance;
  bool _loading = true;
  List<_CredentialRow> _rows = const <_CredentialRow>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final LanDeckRepository repository = AppScope.of(context);
    final List<_CredentialRow> rows = <_CredentialRow>[];
    for (final Service service in repository.services) {
      final List<HttpCredential> credentials = await _store.credentialsFor(
        service.id,
      );
      for (final HttpCredential credential in credentials) {
        rows.add(_CredentialRow(service: service, credential: credential));
      }
    }
    rows.sort((_CredentialRow a, _CredentialRow b) {
      final int byService = a.service.name.compareTo(b.service.name);
      return byService != 0
          ? byService
          : a.credential.host.compareTo(b.credential.host);
    });
    if (!mounted) {
      return;
    }
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _delete(_CredentialRow row) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.key_off_outlined),
        title: const Text('删除登录凭据？'),
        content: Text(
          '将删除「${row.service.name}」在 ${row.credential.host} 保存的账号 '
          '${row.credential.username}。密码不会显示在界面上。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _store.deleteCredential(
      row.service.id,
      host: row.credential.host,
      realm: row.credential.realm,
      username: row.credential.username,
    );
    if (!mounted) {
      return;
    }
    showAppSnackBar(context, '已删除保存的登录凭据');
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('密码管理')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSettingsPageMaxWidth),
            child: _loading
                ? const ListSkeleton()
                : _rows.isEmpty
                ? const EmptyState(
                    icon: Icons.key_off_outlined,
                    title: '还没有保存的密码',
                    message: '在网页登录表单提交后选择保存，或在 HTTP 认证对话框中勾选记住。',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: _rows.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _CredentialRow row = _rows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card.outlined(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: Icon(
                              row.credential.realm == 'web-form'
                                  ? Icons.language_rounded
                                  : Icons.lock_outline_rounded,
                            ),
                            title: Text(row.credential.username),
                            subtitle: Text(
                              '${row.service.name} · ${row.credential.host}\n'
                              '${row.credential.realm == 'web-form' ? '网页登录' : 'HTTP 认证 · ${row.credential.realm}'}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              key: ValueKey<String>(
                                'delete-credential-${row.service.id}-${row.credential.host}-${row.credential.realm}',
                              ),
                              onPressed: () => _delete(row),
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: '删除凭据',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _CredentialRow {
  const _CredentialRow({required this.service, required this.credential});

  final Service service;
  final HttpCredential credential;
}
