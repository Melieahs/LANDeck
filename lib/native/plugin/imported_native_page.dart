import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../services/http_credential_store.dart';
import 'plugin_manifest.dart';

/// Renders a declarative imported plugin. No third-party code is executed:
/// the manifest only describes same-origin HTTP requests and how to display
/// their responses.
class ImportedNativePage extends StatefulWidget {
  const ImportedNativePage({required this.module, required this.service, super.key});

  final ImportedNativeModule module;
  final Service service;

  @override
  State<ImportedNativePage> createState() => _ImportedNativePageState();
}

class _ImportedNativePageState extends State<ImportedNativePage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final http.Client _client = http.Client();
  bool _remember = false;
  bool _busy = false;
  bool _loading = true;
  bool _obscure = true;
  String? _error;
  String _raw = '';
  Map<String, String> _values = <String, String>{};
  HttpCredential? _credential;

  String get _realm => 'plugin:${widget.module.id}';
  Uri get _baseUri => Uri.parse(widget.service.url)..normalizePath();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final Uri? base = _safeBase();
    if (base == null) {
      setState(() {
        _loading = false;
        _error = '服务地址无效';
      });
      return;
    }
    if (widget.module.manifest.basicAuth) {
      _credential = await HttpCredentialStore.instance.find(
        widget.service.id,
        host: _scopeHost(base),
        realm: _realm,
      );
      if (_credential != null) {
        _username.text = _credential!.username;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
    if (!widget.module.manifest.basicAuth || _credential != null) {
      await _fetch();
    }
  }

  Uri? _safeBase() {
    final Uri? uri = widget.service.uri;
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  String _scopeHost(Uri uri) {
    final int port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.host}:$port';
  }

  Future<void> _connect() async {
    final String username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final Uri? base = _safeBase();
    if (base == null) {
      setState(() => _busy = false);
      return;
    }
    final HttpCredential credential = HttpCredential(
      serviceId: widget.service.id,
      host: _scopeHost(base),
      realm: _realm,
      username: username,
      password: _password.text,
      updatedAt: DateTime.now(),
    );
    if (_remember) {
      try {
        await HttpCredentialStore.instance.save(credential);
      } on Object {
        if (mounted) {
          showAppSnackBar(context, '凭据无法安全保存，本次仅用于当前会话');
        }
      }
    }
    _credential = credential;
    if (mounted) {
      setState(() => _busy = false);
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    final PluginManifest manifest = widget.module.manifest;
    final PluginRequest? status = manifest.status;
    final Uri? base = _safeBase();
    if (base == null) {
      return;
    }
    if (status == null) {
      setState(() {
        _loading = false;
        _values = <String, String>{};
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final http.Response response = await _send(status, base);
      if (!mounted) {
        return;
      }
      final String body = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode == 401) {
        setState(() => _error = '需要登录后才能读取状态');
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 400) {
        setState(() => _error = '状态读取失败：HTTP ${response.statusCode}');
        return;
      }
      Object? json;
      try {
        json = jsonDecode(body);
      } on FormatException {
        json = null;
      }
      final Map<String, String> values = <String, String>{};
      for (final PluginField field in manifest.fields) {
        final String? value = field.resolve(json, body);
        if (value != null) {
          values[field.label] = value;
        }
      }
      setState(() {
        _values = values;
        _raw = body;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = '无法连接服务：${_friendlyError(error)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Future<http.Response> _send(PluginRequest request, Uri base) async {
    final Uri uri = request.resolve(base);
    final http.Request message = http.Request(request.method, uri);
    message.headers.addAll(request.headers);
    if (_credential != null) {
      final String token = base64Encode(utf8.encode('${_credential!.username}:${_credential!.password}'));
      message.headers['Authorization'] = 'Basic $token';
    }
    if (request.json != null) {
      message.headers['Content-Type'] = 'application/json; charset=utf-8';
      message.body = jsonEncode(request.json);
    } else if (request.form.isNotEmpty) {
      message.bodyFields = request.form;
    }
    final http.StreamedResponse streamed =
        await _client.send(message).timeout(const Duration(seconds: 15));
    return http.Response.fromStream(streamed);
  }

  Future<void> _runAction(PluginAction action) async {
    final Uri? base = _safeBase();
    if (base == null || _busy) {
      return;
    }
    if (action.confirmText != null && action.confirmText!.isNotEmpty) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(action.label),
          content: Text(action.confirmText!),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续')),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final http.Response response = await _send(action.request, base);
      if (!mounted) {
        return;
      }
      if (response.statusCode == 401) {
        setState(() => _error = '需要登录后才能执行此操作');
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 400) {
        setState(() => _error = '${action.label}失败：HTTP ${response.statusCode}');
        return;
      }
      showAppSnackBar(context, '${action.label}已提交');
      if (action.refreshDelaySeconds > 0) {
        await Future<void>.delayed(Duration(seconds: action.refreshDelaySeconds));
      }
      if (mounted) {
        await _fetch();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = '${action.label}失败：${_friendlyError(error)}');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is http.ClientException) {
      return '网络错误';
    }
    if (error is FormatException) {
      return '响应格式无法识别';
    }
    if (error is PluginManifestException) {
      return error.message;
    }
    return '请检查服务是否可访问';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ThemeData theme = Theme.of(context);
    final PluginManifest manifest = widget.module.manifest;
    final bool needsLogin = manifest.basicAuth && _credential == null;
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          if (needsLogin) _loginCard(theme) else ...<Widget>[
            _statusCard(theme),
            if (manifest.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('操作', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final PluginAction action in manifest.actions)
                        FilledButton.tonalIcon(
                          key: ValueKey<String>('plugin-action-${action.id}'),
                          onPressed: _busy ? null : () => _runAction(action),
                          icon: Icon(pluginActionIcon(action.icon), size: 18),
                          label: Text(action.label),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline_rounded, color: theme.colorScheme.onErrorContainer),
                title: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _error = null),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.verified_user_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '导入模块「${manifest.name}」v${manifest.version} 由声明式配置驱动，'
                      '不会执行第三方代码。它只能向当前服务地址发起请求；请只导入可信来源的插件。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginCard(ThemeData theme) {
    final Uri base = _baseUri;
    final String deviceName = AppScope.of(context).deviceNameFor(widget.service);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('登录 ${widget.module.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${widget.service.name} · $deviceName · ${base.host}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey<String>('plugin-username'),
              controller: _username,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('plugin-password'),
              controller: _password,
              obscureText: _obscure,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remember,
              onChanged: (bool? value) => setState(() => _remember = value ?? false),
              title: const Text('记住登录信息'),
              subtitle: const Text('使用系统安全存储加密保存，仅用于此服务。'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('plugin-connect'),
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('连接'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(ThemeData theme) {
    final PluginManifest manifest = widget.module.manifest;
    final List<MapEntry<String, String>> rows = _values.entries.toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    manifest.status == null ? '模块已连接' : '状态',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('plugin-refresh'),
                  tooltip: '刷新',
                  onPressed: _busy ? null : _fetch,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
                if (manifest.basicAuth)
                  IconButton(
                    tooltip: '更换账号',
                    onPressed: () => setState(() => _credential = null),
                    icon: const Icon(Icons.switch_account_outlined),
                  ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty && manifest.status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '请求成功，但插件声明的字段没有匹配到内容。',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (final MapEntry<String, String> row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: Text(row.key, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(child: SelectableText(row.value, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            if (rows.isEmpty && _raw.isNotEmpty && manifest.status != null) ...<Widget>[
              const Divider(height: 24),
              Text('原始响应', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _raw.length > 4000 ? '${_raw.substring(0, 4000)}…' : _raw,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
