import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/download_task.dart';
import '../models/service.dart';
import '../repositories/service_repository.dart';
import 'download_request_headers.dart';
import 'native_download_bridge.dart';

/// Coordinates persisted download tasks with the Android foreground service.
///
/// One native transfer runs at a time; queued tasks start automatically. The
/// service keeps running when the WebView is closed or the app is backgrounded.
class DownloadCenter {
  DownloadCenter._();

  static final DownloadCenter instance = DownloadCenter._();

  final NativeDownloadBridge _bridge = const NativeDownloadBridge();
  final NativeFileBridge fileBridge = const NativeFileBridge();
  final Uuid _uuid = const Uuid();

  final Map<String, Map<String, String>> _headers =
      <String, Map<String, String>>{};
  final Map<String, int> _misses = <String, int>{};

  LanDeckRepository? _repository;
  Timer? _pollTimer;
  bool _pumping = false;
  bool _polling = false;

  LanDeckRepository? get repository => _repository;

  /// Android 13+ needs an explicit notification permission. Downloads still
  /// work when it is denied; only the system notification is omitted.
  Future<void> requestNotificationPermission() async {
    if (kIsWeb) {
      return;
    }
    try {
      final PermissionStatus status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } on Object {
      // Notification permission is optional for the download itself.
    }
  }

  Future<void> attach(LanDeckRepository repository) async {
    if (identical(_repository, repository)) {
      return;
    }
    _repository = repository;
    await _recover();
  }

  Future<void> _recover() async {
    final LanDeckRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    for (final DownloadTask task in repository.downloads) {
      if (task.status == DownloadStatus.downloading) {
        final Map<String, Object?>? native = await _bridge.query(task.id);
        if (native == null) {
          await repository.updateDownload(
            task.copyWith(
              status: DownloadStatus.failed,
              errorMessage: '下载中断：应用或下载服务已重启',
            ),
          );
        } else {
          await _applyNative(task, native);
        }
      } else if (task.status == DownloadStatus.pending) {
        await repository.updateDownload(
          task.copyWith(
            status: DownloadStatus.failed,
            errorMessage: '下载未开始：应用已重启，请重试',
          ),
        );
      }
    }
    await _pump();
  }

  Future<DownloadTask?> enqueue({
    required Service? service,
    required String url,
    required String fileName,
    required String? mimeType,
    required int? totalBytes,
    required String destinationUri,
    required Map<String, String> headers,
  }) async {
    final LanDeckRepository? repository = _repository;
    if (repository == null) {
      return null;
    }
    final DateTime now = DateTime.now();
    final DownloadTask task = DownloadTask(
      id: _uuid.v4(),
      serviceId: service?.id,
      serviceName: service?.name ?? '',
      fileName: fileName,
      url: url,
      mimeType: mimeType,
      totalBytes: totalBytes,
      status: DownloadStatus.pending,
      createdAt: now,
      destinationUri: destinationUri,
    );
    await repository.addDownload(task);
    _headers[task.id] = headers;
    await _pump();
    return repository.downloadById(task.id);
  }

  Future<void> retry(DownloadTask task) async {
    final LanDeckRepository? repository = _repository;
    if (repository == null || task.isActive) {
      return;
    }
    if (_headers[task.id] == null) {
      final Service? service = task.serviceId == null
          ? null
          : repository.serviceById(task.serviceId!);
      if (service != null) {
        _headers[task.id] = await DownloadRequestHeaders.build(
          service: service,
          url: task.url,
        );
      }
    }
    await repository.updateDownload(
      task.copyWith(
        status: DownloadStatus.pending,
        downloadedBytes: 0,
        clearError: true,
        clearCompletedAt: true,
        clearTotal: task.totalBytes == null,
      ),
    );
    _misses.remove(task.id);
    await _pump();
  }

  Future<void> cancel(DownloadTask task) async {
    final LanDeckRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    if (task.status == DownloadStatus.downloading) {
      await _bridge.cancel(task.id);
    }
    await repository.updateDownload(
      task.copyWith(
        status: DownloadStatus.cancelled,
        errorMessage: '已取消',
        completedAt: DateTime.now(),
      ),
    );
    _misses.remove(task.id);
    await _pump();
  }

  Future<void> remove(DownloadTask task) async {
    final LanDeckRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    if (task.status == DownloadStatus.downloading) {
      await _bridge.cancel(task.id);
    }
    _headers.remove(task.id);
    _misses.remove(task.id);
    await repository.deleteDownload(task.id);
    await _pump();
  }

  Future<bool> openFile(DownloadTask task) async {
    final String? uri = task.destinationUri;
    if (uri == null) {
      return false;
    }
    return _bridge.openFile(uri: uri, mimeType: task.mimeType);
  }

  Future<bool> shareFile(DownloadTask task) async {
    final String? uri = task.destinationUri;
    if (uri == null) {
      return false;
    }
    return _bridge.shareFile(
      uri: uri,
      mimeType: task.mimeType,
      fileName: task.fileName,
    );
  }

  Future<void> _pump() async {
    final LanDeckRepository? repository = _repository;
    if (repository == null || _pumping) {
      return;
    }
    if (repository.downloads.any(
      (DownloadTask task) => task.status == DownloadStatus.downloading,
    )) {
      _startPolling();
      return;
    }
    DownloadTask? next;
    for (final DownloadTask task in repository.downloads.reversed) {
      if (task.status == DownloadStatus.pending) {
        next = task;
        break;
      }
    }
    if (next == null) {
      _stopPolling();
      return;
    }

    _pumping = true;
    try {
      final String? destination = next.destinationUri;
      if (destination == null) {
        await repository.updateDownload(
          next.copyWith(
            status: DownloadStatus.failed,
            errorMessage: '保存位置不可用，请重新选择',
          ),
        );
        return;
      }
      final bool started = await _bridge.start(
        taskId: next.id,
        url: next.url,
        fileName: next.fileName,
        mimeType: next.mimeType,
        destinationUri: destination,
        headers: _headers[next.id] ?? const <String, String>{},
      );
      if (!started) {
        await repository.updateDownload(
          next.copyWith(
            status: DownloadStatus.failed,
            errorMessage: '无法启动系统下载服务',
          ),
        );
      } else {
        await repository.updateDownload(
          next.copyWith(status: DownloadStatus.downloading),
        );
        _startPolling();
      }
    } finally {
      _pumping = false;
    }
    // A failed task should not stop the queue.
    await _pump();
  }

  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }
    _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      unawaited(_poll());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    final LanDeckRepository? repository = _repository;
    if (repository == null || _polling) {
      return;
    }
    _polling = true;
    try {
      final List<DownloadTask> active = repository.downloads
          .where(
            (DownloadTask task) => task.status == DownloadStatus.downloading,
          )
          .toList();
      if (active.isEmpty) {
        _stopPolling();
        await _pump();
        return;
      }
      for (final DownloadTask task in active) {
        final Map<String, Object?>? native = await _bridge.query(task.id);
        if (native == null) {
          final int misses = (_misses[task.id] ?? 0) + 1;
          _misses[task.id] = misses;
          if (misses >= 4) {
            await repository.updateDownload(
              task.copyWith(
                status: DownloadStatus.failed,
                errorMessage: '下载服务未响应，请重试',
              ),
            );
          }
          continue;
        }
        _misses.remove(task.id);
        await _applyNative(task, native);
      }
    } finally {
      _polling = false;
    }
    await _pump();
  }

  Future<void> _applyNative(
    DownloadTask task,
    Map<String, Object?> native,
  ) async {
    final LanDeckRepository? repository = _repository;
    if (repository == null) {
      return;
    }
    final String status = (native['status'] as String?) ?? '';
    final int downloaded = (native['downloaded'] as num?)?.toInt() ?? 0;
    final int? total = (native['total'] as num?)?.toInt();
    final String? error = native['error'] as String?;
    final DownloadStatus next = switch (status) {
      'completed' => DownloadStatus.completed,
      'failed' => DownloadStatus.failed,
      'cancelled' => DownloadStatus.cancelled,
      _ => DownloadStatus.downloading,
    };
    if (next == DownloadStatus.downloading &&
        task.downloadedBytes == downloaded &&
        task.totalBytes == total) {
      return;
    }
    await repository.updateDownload(
      task.copyWith(
        status: next,
        downloadedBytes: downloaded,
        totalBytes: total,
        errorMessage: next == DownloadStatus.failed
            ? (error ?? '下载失败')
            : null,
        completedAt: next == DownloadStatus.completed
            ? DateTime.now()
            : null,
        clearError: next != DownloadStatus.failed,
      ),
    );
  }
}
