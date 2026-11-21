import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../models/http_credential.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import 'padavan_client.dart';

/// Native control surface for a Padavan router service.
///
/// It talks to the router's own web UI over HTTP Basic and never edits the
/// router's configuration; the only operations are the three actions exposed by
/// the WAN status page.
class PadavanNativePage extends StatefulWidget {
  const PadavanNativePage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<PadavanNativePage> createState() => _PadavanNativePageState();
}

class _PadavanNativePageState extends State<PadavanNativePage> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  PadavanClient? _client;
  PadavanStatus? _status;
  String? _error;
  String? _realm;
  DateTime? _updatedAt;
  bool _busy = false;
  bool _remember = false;
  bool _obscure = true;
  bool _authenticated = false;
  bool _loadedCredentials = false;

  Service? _service;
  LanDeckRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedCredentials) {
      return;
    }
    _loadedCredentials = true;
    _repository = AppScope.of(context);
    _service = _repository!.serviceById(widget.serviceId);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final List<HttpCredential> credentials =
        await HttpCredentialStore.instance.credentialsFor(service.id);
    if (!mounted) {
      return;
    }
    final String host = _routerHost(service);
    HttpCredential? saved;
    for (final HttpCredential credential in credentials) {
      if (credential.normalizedHost == host.toLowerCase()) {
        saved = credential;
        break;
      }
    }
    saved ??= credentials.isEmpty ? null : credentials.first;
    if (saved == null) {
      setState(() {});
      return;
    }
    _username.text = saved.username;
    _password.text = saved.password;
    _realm = saved.realm;
    await _connect(auto: true);
  }

  @override
  void dispose() {
    _client?.close();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }


  String _routerHost(Service service) {
    final Uri? uri = service.uri;
    if (uri == null) {
      return service.address;
    }
    return uri.host;
  }

  Uri? _origin(Service service) {
    final Uri? uri = service.uri;
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null);
  }

  PadavanClient _createClient(Service service) {
    final Uri? origin = _origin(service);
    if (origin == null) {
      throw const PadavanException('服务地址无效');
    }
    _client?.close();
    return _client = PadavanClient(
      baseUri: origin,
      username: _username.text.trim(),
      password: _password.text,
    );
  }

  Future<void> _connect({bool auto = false}) async {
    final Service? service = _service;
    if (service == null || _busy) {
      return;
    }
    if (_username.text.trim().isEmpty) {
      setState(() => _error = '请输入路由器用户名');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PadavanClient client = _createClient(service);
      final PadavanStatus status = await client.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _authenticated = true;
        _status = status;
        _updatedAt = DateTime.now();
        _error = null;
      });
      if (!auto && _remember) {
        try {
          await _saveCredential(service);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('登录成功，但无法安全保存凭据')),
            );
          }
        }
      }
    } on PadavanAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authenticated = false;
        _status = null;
        _realm = error.realm ?? _realm;
        _error = error.message;
      });
    } on PadavanException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authenticated = false;
        _status = null;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authenticated = false;
        _status = null;
        _error = '无法连接路由器：$error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveCredential(Service service) async {
    final String host = _routerHost(service);
    await HttpCredentialStore.instance.save(
      HttpCredential(
        serviceId: service.id,
        host: host,
        realm: _realm ?? 'Padavan',
        username: _username.text.trim(),
        password: _password.text,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_busy || !_authenticated) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PadavanStatus status = await _client!.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _updatedAt = DateTime.now();
      });
    } on PadavanException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _runAction(String action, String label) async {
    if (_busy || !_authenticated || _client == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PadavanActionResult result = await _client!.perform(action);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label已提交，${result.reloadSeconds} 秒后刷新状态'),
        ),
      );
      await Future<void>.delayed(
        Duration(seconds: result.reloadSeconds + 1),
      );
      if (mounted) {
        final PadavanStatus status = await _client!.fetchStatus();
        if (!mounted) {
          return;
        }
        setState(() {
          _status = status;
          _updatedAt = DateTime.now();
        });
      }
    } on PadavanException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Service? service = _service;
    if (service == null) {
      return const Center(child: Text('服务不存在或已被删除'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        if (!_authenticated) _buildLoginCard(theme, service),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        if (_authenticated && _status != null) ...<Widget>[
          const SizedBox(height: 4),
          _buildStatusCard(theme, _status!),
          const SizedBox(height: 14),
          _buildActions(theme),
          if (_updatedAt != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '状态更新于 ${_updatedAt!.hour.toString().padLeft(2, '0')}:'
              '${_updatedAt!.minute.toString().padLeft(2, '0')}:'
              '${_updatedAt!.second.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        if (!_authenticated && _busy)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildLoginCard(ThemeData theme, Service service) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.router_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('登录 Padavan', style: theme.textTheme.titleMedium),
                      Text(
                        '${service.name} · ${service.address}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('padavan-username'),
              controller: _username,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('padavan-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              onSubmitted: (_) => _connect(),
              decoration: InputDecoration(
                labelText: '密码',
                suffixIcon: IconButton(
                  tooltip: _obscure ? '显示密码' : '隐藏密码',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            SwitchListTile(
              key: const Key('padavan-remember'),
              contentPadding: EdgeInsets.zero,
              title: const Text('记住登录信息'),
              subtitle: const Text('仅保存在本机加密存储中'),
              value: _remember,
              onChanged: _busy
                  ? null
                  : (bool value) => setState(() => _remember = value),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('padavan-connect'),
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.login_rounded),
                label: const Text('连接并读取状态'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, PadavanStatus status) {
    final Color statusColor = status.connected
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lan_rounded, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('WAN 状态', style: theme.textTheme.titleMedium),
                      Text(
                        status.stateLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('padavan-refresh'),
                  tooltip: '刷新状态',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(label: '连接类型', value: status.type),
            _InfoRow(label: 'WAN IPv4', value: status.wanIp),
            _InfoRow(label: '网关', value: status.gateway),
            _InfoRow(label: 'DNS', value: status.dns),
            _InfoRow(label: '连接时长', value: status.uptimeLabel),
            _InfoRow(label: '有线链路', value: status.etherLink),
            _InfoRow(label: '无线中继', value: status.apCliLink),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _authenticated = false;
                          _status = null;
                        });
                      },
                child: const Text('更换账号'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final PadavanStatus? status = _status;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('WAN 操作', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '操作会直接调用路由器 Web 管理接口，可能造成短暂断网。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonal(
                    key: const Key('padavan-wan-reconnect'),
                    onPressed: _busy
                        ? null
                        : () => _runAction(
                            PadavanClient.wanReconnect,
                            '重连 WAN',
                          ),
                    child: const Text('重连 WAN'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('padavan-wan-disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _runAction(
                            PadavanClient.wanDisconnect,
                            '断开 WAN',
                          ),
                    child: const Text('断开 WAN'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('padavan-wisp-reassoc'),
                onPressed: _busy
                    ? null
                    : () => _runAction(
                        PadavanClient.wispReassoc,
                        '重新关联中继',
                      ),
                icon: const Icon(Icons.wifi_find_rounded),
                label: const Text('重新关联无线中继'),
              ),
            ),
            if (status != null && status.apCliLink == '—')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '当前未检测到 WISP/APCLI 链路；按钮可能不会产生效果。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
