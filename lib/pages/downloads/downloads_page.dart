import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/download_task.dart';
import '../../repositories/service_repository.dart';
import '../../services/download_center.dart';
import '../../widgets/empty_state.dart';

/// Persistent download queue. All progress is reported by the native
/// foreground service; nothing here is simulated.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: repository,
            builder: (BuildContext context, Widget? child) {
              final bool hasFinished = repository.downloads.any(
                (DownloadTask task) => !task.isActive,
              );
              if (!hasFinished) {
                return const SizedBox.shrink();
              }
              return IconButton(
                key: const ValueKey<String>('clear-downloads'),
                tooltip: '清除已结束记录',
                onPressed: () => _confirmClear(context, repository),
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (BuildContext context, Widget? child) {
          final List<DownloadTask> tasks = repository.downloads;
          if (tasks.isEmpty) {
            return const _EmptyDownloads();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              return _DownloadTile(
                key: ValueKey<String>('download-task-${tasks[index].id}'),
                task: tasks[index],
                repository: repository,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    LanDeckRepository repository,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清除下载记录？'),
        content: const Text('只删除下载记录，不会删除已经保存到本地的文件。正在下载的任务会保留。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repository.clearCompletedDownloads();
    }
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.task,
    required this.repository,
    super.key,
  });

  final DownloadTask task;
  final LanDeckRepository repository;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool active = task.isActive;
    final bool completed = task.status == DownloadStatus.completed;
    final String subtitle = switch (task.status) {
      DownloadStatus.failed => task.errorMessage ?? '下载失败',
      DownloadStatus.cancelled => '已取消',
      DownloadStatus.completed => task.sizeLabel,
      _ => '${task.sizeLabel} · ${task.serviceName.isEmpty ? '本地下载' : task.serviceName}',
    };
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: completed ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completed
                      ? Icons.insert_drive_file_outlined
                      : task.status == DownloadStatus.failed
                      ? Icons.error_outline_rounded
                      : Icons.downloading_rounded,
                  color: task.status == DownloadStatus.failed
                      ? scheme.error
                      : scheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: task.status == DownloadStatus.failed
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (active) ...<Widget>[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _StatusChip(status: task.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.displayUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _DownloadMenu(
                task: task,
                onOpen: () => _open(context),
                onShare: () => _share(context),
                onRetry: () => DownloadCenter.instance.retry(task),
                onCancel: () => DownloadCenter.instance.cancel(task),
                onCopy: () => _copy(context),
                onDelete: () => _delete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final bool ok = await DownloadCenter.instance.openFile(task);
    if (!ok && context.mounted) {
      showAppSnackBar(context, '无法打开文件，可能已被移动或删除');
    }
  }

  Future<void> _share(BuildContext context) async {
    final bool ok = await DownloadCenter.instance.shareFile(task);
    if (!ok && context.mounted) {
      showAppSnackBar(context, '无法分享文件');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: task.displayUrl));
    if (context.mounted) {
      showAppSnackBar(context, '链接已复制（已隐藏查询参数）');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除下载记录？'),
        content: const Text('不会删除已经保存到本地的文件。'),
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
    if (ok == true) {
      await DownloadCenter.instance.remove(task);
    }
  }
}

class _DownloadMenu extends StatelessWidget {
  const _DownloadMenu({
    required this.task,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
    required this.onCancel,
    required this.onCopy,
    required this.onDelete,
  });

  final DownloadTask task;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool completed = task.status == DownloadStatus.completed;
    final bool active = task.isActive;
    return PopupMenuButton<String>(
      tooltip: '下载操作',
      onSelected: (String value) {
        switch (value) {
          case 'open':
            onOpen();
          case 'share':
            onShare();
          case 'retry':
            onRetry();
          case 'cancel':
            onCancel();
          case 'copy':
            onCopy();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (completed)
          const PopupMenuItem<String>(
            value: 'open',
            child: ListTile(
              leading: Icon(Icons.open_in_new_rounded),
              title: Text('打开文件'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (completed)
          const PopupMenuItem<String>(
            value: 'share',
            child: ListTile(
              leading: Icon(Icons.ios_share_rounded),
              title: Text('分享文件'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled)
          const PopupMenuItem<String>(
            value: 'retry',
            child: ListTile(
              leading: Icon(Icons.refresh_rounded),
              title: Text('重新下载'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (active)
          const PopupMenuItem<String>(
            value: 'cancel',
            child: ListTile(
              leading: Icon(Icons.stop_circle_outlined),
              title: Text('取消下载'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.link_rounded),
            title: Text('复制链接'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('删除记录'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      DownloadStatus.completed => scheme.primary,
      DownloadStatus.failed => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.download_done_rounded,
      title: '还没有下载任务',
      message: '在网页中点开文件下载链接，任务会在这里显示，并在后台继续。',
    );
  }
}
