import 'package:material_ui/material_ui.dart';

import '../../../models/download_task.dart';

class DownloadConfirmation {
  const DownloadConfirmation({
    required this.fileName,
    required this.url,
    required this.mimeType,
    required this.totalBytes,
    required this.risky,
  });

  final String fileName;
  final String url;
  final String? mimeType;
  final int? totalBytes;
  final bool risky;
}

Future<bool> showDownloadConfirmDialog(
  BuildContext context, {
  required String serviceName,
  required DownloadConfirmation data,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        key: const ValueKey<String>('download-confirm-dialog'),
        icon: const Icon(Icons.download_rounded),
        title: const Text('下载文件'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.insert_drive_file_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.fileName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(label: '来源服务', value: serviceName),
              _InfoRow(
                label: '下载地址',
                value: Uri.tryParse(data.url)?.host ?? data.url,
              ),
              _InfoRow(label: '文件类型', value: data.mimeType ?? '未知类型'),
              _InfoRow(
                label: '文件大小',
                value: data.totalBytes == null
                    ? '未知（下载时确定）'
                    : formatBytes(data.totalBytes!),
              ),
              const _InfoRow(label: '保存位置', value: '确认后选择保存位置'),
              if (data.risky) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '这是可执行文件或固件类文件。LANDeck 不会自动打开、安装或刷入，请确认来源可信。',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '下载会使用当前网页的 Cookie 与已保存的 HTTP 认证信息，在后台继续。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('download-confirm-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const ValueKey<String>('download-confirm-start'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('下载'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
