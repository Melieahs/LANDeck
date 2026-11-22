import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../repositories/service_repository.dart';
import 'credential_manager_page.dart';
import 'ftp_backup_page.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final LanDeckRepository repository = AppScope.of(context);
      final String json = const JsonEncoder.withIndent('  ')
          .convert(repository.exportBackup());
      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '')
          .replaceAll('T', '-');
      final File file = File('${dir.path}/LANDeck-backup-$stamp.json');
      await file.writeAsString(json, flush: true);
      if (!mounted) {
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          title: 'LANDeck 配置备份',
          text: '设备与服务配置备份（不含密码和下载记录）',
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        ),
      );
      if (mounted) {
        showAppSnackBar(context, '备份已生成：${file.path.split('/').last}');
      }
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, '导出失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    if (_busy) {
      return;
    }
    final LanDeckRepository repository = AppScope.of(context);
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: '选择 LANDeck 备份',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        icon: const Icon(Icons.restore_rounded),
        title: const Text('导入配置？'),
        content: const Text('导入会替换当前的设备和全部服务。下载记录、已保存的密码和 FTP 设置不会被导入或删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('替换并导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String content = utf8.decode(await picked.readAsBytes());
      final Object? decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw const FormatException('备份内容不是 JSON 对象');
      }
      final BackupImportResult result = await repository.importBackup(
        Map<String, Object?>.from(decoded),
      );
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        '已导入 ${result.devices} 台设备、${result.services} 个服务',
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

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('数据存储')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSettingsPageMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: <Widget>[
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.storage_rounded, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${repository.services.length} 个服务 · '
                            '${repository.devices.length} 台设备\n'
                            '配置保存在本机；密码使用系统安全存储单独加密。',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('备份与恢复', style: text.titleSmall),
                const SizedBox(height: 8),
                Card.outlined(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        key: const ValueKey<String>('storage-ftp'),
                        leading: const Icon(Icons.swap_horiz_rounded),
                        title: const Text('FTP 数据互通'),
                        subtitle: const Text('通过 FTP 服务器备份和恢复配置'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const FtpBackupPage(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey<String>('storage-export'),
                        leading: const Icon(Icons.ios_share_rounded),
                        title: const Text('导出配置'),
                        subtitle: const Text('生成 JSON 备份并通过系统分享'),
                        trailing: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _busy ? null : _export,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey<String>('storage-import'),
                        leading: const Icon(Icons.restore_rounded),
                        title: const Text('导入配置'),
                        subtitle: const Text('从 JSON 备份替换设备与服务'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _busy ? null : _import,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('安全', style: text.titleSmall),
                const SizedBox(height: 8),
                Card.outlined(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    key: const ValueKey<String>('storage-passwords'),
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('密码管理'),
                    subtitle: const Text('查看和删除已保存的网页与 HTTP 认证账号'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            const CredentialManagerPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '备份不包含密码和下载记录；导入不会覆盖密码库。',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
