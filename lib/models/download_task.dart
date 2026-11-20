import 'dart:convert';

/// Lifecycle of a real file download handled by the Android foreground service.
enum DownloadStatus { pending, downloading, completed, failed, cancelled }

extension DownloadStatusLabel on DownloadStatus {
  String get label => switch (this) {
    DownloadStatus.pending => '等待中',
    DownloadStatus.downloading => '下载中',
    DownloadStatus.completed => '已完成',
    DownloadStatus.failed => '失败',
    DownloadStatus.cancelled => '已取消',
  };

  bool get isActive =>
      this == DownloadStatus.pending || this == DownloadStatus.downloading;
}

/// Persisted download task. The URL is kept locally so failed tasks can be
/// retried; the UI redacts query strings and fragments before displaying it.
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.fileName,
    required this.url,
    required this.status,
    required this.createdAt,
    this.serviceId,
    this.serviceName = '',
    this.mimeType,
    this.totalBytes,
    this.downloadedBytes = 0,
    this.completedAt,
    this.destinationUri,
    this.errorMessage,
  });

  final String id;
  final String? serviceId;
  final String serviceName;
  final String fileName;
  final String url;
  final String? mimeType;
  final int? totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? destinationUri;
  final String? errorMessage;

  bool get isActive => status.isActive;

  double? get progress {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (downloadedBytes / total).clamp(0, 1).toDouble();
  }

  String get sizeLabel {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return downloadedBytes > 0 ? '已下载 ${formatBytes(downloadedBytes)}' : '大小未知';
    }
    return '${formatBytes(downloadedBytes)} / ${formatBytes(total)}';
  }

  /// Host + path only: query strings can contain signed tokens.
  String get displayUrl {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return url;
    }
    final String path = uri.path.isEmpty ? '/' : uri.path;
    final String port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port$path';
  }

  DownloadTask copyWith({
    String? fileName,
    String? url,
    String? serviceId,
    String? serviceName,
    String? mimeType,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? completedAt,
    String? destinationUri,
    String? errorMessage,
    bool clearError = false,
    bool clearCompletedAt = false,
    bool clearDestination = false,
    bool clearTotal = false,
  }) {
    return DownloadTask(
      id: id,
      fileName: fileName ?? this.fileName,
      url: url ?? this.url,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      mimeType: mimeType ?? this.mimeType,
      totalBytes: clearTotal ? null : (totalBytes ?? this.totalBytes),
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      destinationUri: clearDestination
          ? null
          : (destinationUri ?? this.destinationUri),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'fileName': fileName,
    'url': url,
    'mimeType': mimeType,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'destinationUri': destinationUri,
    'errorMessage': errorMessage,
  };

  factory DownloadTask.fromMap(Map<String, Object?> map) {
    return DownloadTask(
      id: map['id'] as String? ?? '',
      serviceId: map['serviceId'] as String?,
      serviceName: map['serviceName'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'download',
      url: map['url'] as String? ?? '',
      mimeType: map['mimeType'] as String?,
      totalBytes: (map['totalBytes'] as num?)?.toInt(),
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.values.firstWhere(
        (DownloadStatus value) => value.name == map['status'],
        orElse: () => DownloadStatus.failed,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
      destinationUri: map['destinationUri'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() =>
      'DownloadTask($id, $fileName, ${status.name}, $downloadedBytes/$totalBytes)';
}

String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const List<String> units = <String>['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 10
      ? value.toStringAsFixed(1)
      : value.toStringAsFixed(2);
  return '$text ${units[unit]}';
}
