import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../repositories/service_repository.dart';
import '../../services/ftp_backup_service.dart';

class FtpBackupPage extends StatefulWidget {
  const FtpBackupPage({super.key});

  @override
  State<FtpBackupPage> createState() => _FtpBackupPageState();
}

class _FtpBackupPageState extends State<FtpBackupPage> {
  final FtpSettingsStore _store = const FtpSettingsStore();
  final FtpBackupService _service = const FtpBackupService();
  final TextEditingController _host = TextEditingController();
  final TextEditingController _port = TextEditingController(text: '21');
  final TextEditingController _user = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _directory = TextEditingController(text: '/');
  final TextEditingController _fileName =
      TextEditingController(text: 'landeck-backup.json');

  FtpSecurity _security = FtpSecurity.ftp;
  bool _obscure = true;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    _directory.dispose();
    _fileName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final FtpConfig config = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _host.text = config.host;
      _port.text = config.port.toString();
      _user.text = config.username;
      _password.text = config.password;
      _directory.text = config.remoteDirectory;
      _fileName.text = config.fileName;
      _security = config.security;
    });
  }

  FtpConfig? _readConfig() {
    final int? port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty || port == null || port < 1 || port > 65535) {
      showAppSnackBar(context, '请填写有效的 FTP 地址和端口');
      return null;
    }
    if (_fileName.text.trim().isEmpty) {
      showAppSnackBar(context, '请填写备份文件名');
      return null;
    }
    return FtpConfig(
      host: _host.text.trim(),
      port: port,
      username: _user.text.trim(),
      password: _password.text,
      remoteDirectory: _directory.text.trim().isEmpty
          ? '/'
          : _directory.text.trim(),
      fileName: _fileName.text.trim(),
      security: _security,
    );
  }

  Future<void> _run(
    String label,
    Future<void> Function(FtpConfig config) action,
  ) async {
    final FtpConfig? config = _readConfig();
    if (config == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    try {
      await _store.save(config);
      await action(config);
      if (!mounted) {
        return;
      }
      setState(() => _status = '$label完成');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = null);
      showAppSnackBar(context, '$label失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _test() {
    return _run('连接测试', (FtpConfig config) async {
      await _service.testConnection(config);
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'FTP 连接成功');
    });
  }

  Future<void> _backup() {
    return _run('备份', (FtpConfig config) async {
      final LanDeckRepository repository = AppScope.of(context);
      await _service.uploadBackup(config, repository.exportBackup());
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        '已备份 ${repository.devices.length} 台设备、'
        '${repository.services.length} 个服务',
      );
    });
  }

  Future<void> _restore() {
    return _run('恢复', (FtpConfig config) async {
      final Map<String, Object?> snapshot = await _service.downloadBackup(config);
      if (!mounted) {
        return;
      }
      final bool confirmed = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('从 FTP 恢复数据？'),
              content: const Text(
                '这会用备份中的设备与服务替换本机现有配置。'
                '下载记录和 HTTP 登录凭据不会被修改。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('替换并恢复'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) {
        return;
      }
      final BackupImportResult result =
          await AppScope.of(context).importBackup(snapshot);
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        '已恢复 ${result.devices} 台设备、${result.services} 个服务',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('FTP 数据互通')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.swap_horiz_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '把设备与服务配置备份到 FTP，换机或重装后从 FTP 恢复。'
                            '不包含下载文件、HTTP 密码或本地主题设置。',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('ftp-host'),
                  controller: _host,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'FTP 地址',
                    hintText: '192.168.1.10 或 nas.local',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: const ValueKey<String>('ftp-port'),
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '端口'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<FtpSecurity>(
                        key: const ValueKey<String>('ftp-security'),
                        initialValue: _security,
                        decoration: const InputDecoration(labelText: '连接方式'),
                        items: FtpSecurity.values
                            .map(
                              (FtpSecurity value) => DropdownMenuItem<FtpSecurity>(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (FtpSecurity? value) {
                          if (value != null) {
                            setState(() => _security = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('ftp-user'),
                  controller: _user,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '匿名可留空',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('ftp-password'),
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('ftp-directory'),
                  controller: _directory,
                  decoration: const InputDecoration(
                    labelText: '远程目录',
                    hintText: '/',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('ftp-filename'),
                  controller: _fileName,
                  decoration: const InputDecoration(
                    labelText: '备份文件名',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey<String>('ftp-test'),
                  onPressed: _busy ? null : _test,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('测试连接'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey<String>('ftp-backup'),
                        onPressed: _busy ? null : _backup,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('备份到 FTP'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('ftp-restore'),
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('从 FTP 恢复'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...<Widget>[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
