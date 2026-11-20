import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/download_task.dart';
import 'package:landeck/services/download_utils.dart';

void main() {
  group('download filenames', () {
    test('prefers RFC 5987 filename* and decodes UTF-8', () {
      expect(
        fileNameFromDisposition(
          "attachment; filename*=UTF-8''%E4%B8%AD%E6%96%87%E6%8A%A5%E5%91%8A.txt",
        ),
        '中文报告.txt',
      );
    });

    test('handles quoted and unquoted ASCII filenames', () {
      expect(fileNameFromDisposition('attachment; filename="fw.bin"'), 'fw.bin');
      expect(fileNameFromDisposition('attachment; filename=fw.bin'), 'fw.bin');
    });

    test('sanitizes traversal and control characters', () {
      expect(safeFileName('../../etc/passwd'), '_.._etc_passwd');
      expect(safeFileName('..\\evil\n.exe'), '_evil.exe');
      expect(safeFileName('   '), 'download');
    });

    test('derives a name from a percent-encoded URL', () {
      expect(
        fileNameFromUrl('http://nas.local/files/%E5%9B%BA%E4%BB%B6.bin?token=1'),
        '固件.bin',
      );
      expect(fileNameFromUrl('http://nas.local/'), 'download');
    });
  });

  group('download detection', () {
    test('detects file extensions and download paths', () {
      expect(looksLikeDownloadUrl('http://nas.local/a.zip'), isTrue);
      expect(looksLikeDownloadUrl('http://nas.local/download?id=3'), isTrue);
      expect(looksLikeDownloadUrl('http://nas.local/index.html'), isFalse);
    });

    test('probes extensionless and handler URLs', () {
      expect(shouldProbeForAttachment('http://nas.local/files/latest'), isTrue);
      expect(shouldProbeForAttachment('http://nas.local/get.php?id=9'), isTrue);
      expect(shouldProbeForAttachment('http://nas.local/home'), isTrue);
      expect(shouldProbeForAttachment('http://nas.local/logo.png'), isFalse);
    });

    test('flags executable/firmware names', () {
      expect(isRiskyFileName('update.apk'), isTrue);
      expect(isRiskyFileName('firmware.img'), isTrue);
      expect(isRiskyFileName('photo.jpg'), isFalse);
    });

    test('maps common MIME types', () {
      expect(mimeForFileName('a.pdf'), 'application/pdf');
      expect(mimeForFileName('a.apk'), 'application/vnd.android.package-archive');
      expect(mimeForFileName('unknown'), isNull);
    });
  });

  group('download task', () {
    DownloadTask task({
      int? total,
      int downloaded = 0,
      DownloadStatus status = DownloadStatus.downloading,
    }) {
      return DownloadTask(
        id: 't1',
        fileName: 'file.bin',
        url: 'http://nas.local/files/file.bin?token=secret#frag',
        status: status,
        totalBytes: total,
        downloadedBytes: downloaded,
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    test('reports real progress and hides query secrets', () {
      final DownloadTask item = task(total: 1000, downloaded: 250);
      expect(item.progress, 0.25);
      expect(item.sizeLabel, '250 B / 1000 B');
      expect(item.displayUrl, 'http://nas.local/files/file.bin');
      expect(item.displayUrl.contains('secret'), isFalse);
    });

    test('serializes and restores a task', () {
      final DownloadTask original = task(total: 100, downloaded: 100).copyWith(
        status: DownloadStatus.completed,
        completedAt: DateTime.utc(2026, 1, 2),
        destinationUri: 'content://downloads/1',
      );
      final DownloadTask restored = DownloadTask.fromMap(original.toMap());
      expect(restored.status, DownloadStatus.completed);
      expect(restored.destinationUri, 'content://downloads/1');
      expect(restored.progress, 1);
    });
  });
}
