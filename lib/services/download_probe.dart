import 'dart:async';
import 'dart:io';

import 'download_utils.dart';

class DownloadProbeResult {
  const DownloadProbeResult({
    required this.url,
    required this.fileName,
    required this.attachment,
    this.mimeType,
    this.totalBytes,
    this.contentDisposition,
    this.statusCode,
    this.authChallenge,
    this.nameKnown = false,
  });

  final String url;
  final String fileName;
  final bool attachment;
  final String? mimeType;
  final int? totalBytes;
  final String? contentDisposition;
  final int? statusCode;
  final String? authChallenge;

  /// True when a real filename came from Content-Disposition or the URL.
  final bool nameKnown;
}

/// Reads response metadata without downloading the body. The WebView's public
/// download callback does not expose Content-Disposition, so this HEAD (with a
/// ranged GET fallback) is used only to build an honest confirmation sheet.
class DownloadProbe {
  DownloadProbe({this.headers = const <String, String>{}});

  final Map<String, String> headers;

  Future<DownloadProbeResult> probe(
    Uri uri, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 2)
      ..userAgent = headers['User-Agent'];
    client.badCertificateCallback = (_, _, _) => _isPrivateHost(uri.host);
    try {
      final _ProbeHeaders? head = await _request(client, uri, method: 'HEAD');
      _ProbeHeaders? response = head;
      // Some appliance download endpoints implement only GET and answer HEAD
      // with 405. A ranged GET against those one-shot endpoints starts (and
      // then cancels) the real transfer, so the later native GET fails. Keep
      // the HEAD metadata and let the native service perform the only GET.
      final bool headUnsupported =
          head != null && (head.statusCode == 405 || head.statusCode == 501);
      final bool destructiveFallback =
          head == null || (head.statusCode >= 400 && !headUnsupported);
      if (destructiveFallback) {
        response = await _request(
          client,
          uri,
          method: 'GET',
          extraHeaders: const <String, String>{'Range': 'bytes=0-0'},
        );
      } else if (headUnsupported) {
        // HEAD failed on a GET-only endpoint; its JSON error body metadata is
        // not the file. Let the native GET discover the real headers.
        response = null;
      }
      if (response == null && !headUnsupported) {
        response = head;
      }
      return _result(uri, response);
    } finally {
      client.close(force: true);
    }
  }

  Future<_ProbeHeaders?> _request(
    HttpClient client,
    Uri uri, {
    required String method,
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      headers.forEach((String key, String value) {
        if (value.isNotEmpty) {
          request.headers.set(key, value);
        }
      });
      extraHeaders.forEach(request.headers.set);
      request.followRedirects = true;
      request.maxRedirects = 4;
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      final _ProbeHeaders result = _ProbeHeaders(
        statusCode: response.statusCode,
        contentDisposition: response.headers.value('content-disposition'),
        contentType: response.headers.contentType?.mimeType,
        contentLength: response.contentLength >= 0
            ? response.contentLength
            : int.tryParse(
                response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
              ),
        contentRange: response.headers.value('content-range'),
        authChallenge: response.headers.value('www-authenticate'),
      );
      // A ranged GET only needs the headers; cancel the body immediately.
      if (method == 'GET') {
        await response.listen(null).cancel();
      }
      return result;
    } on Object {
      return null;
    }
  }

  DownloadProbeResult _result(Uri uri, _ProbeHeaders? response) {
    final String disposition = response?.contentDisposition ?? '';
    final String dispositionName = fileNameFromDisposition(disposition);
    String fallbackName = fileNameFromUrl(uri.toString());
    if (fallbackName.toLowerCase() == 'download' ||
        fallbackName.toLowerCase() == 'file') {
      final String queryName = <String>['filename', 'file', 'name']
          .map((String key) => uri.queryParameters[key] ?? '')
          .firstWhere(
            (String value) => value.trim().isNotEmpty,
            orElse: () => '',
          );
      if (queryName.isNotEmpty) {
        fallbackName = Uri.decodeComponent(queryName);
      } else {
        fallbackName = '下载文件_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
    final String name = safeFileName(
      dispositionName.isNotEmpty ? dispositionName : fallbackName,
    );
    final String? mime =
        _cleanMime(response?.contentType) ?? mimeForFileName(name);
    final bool attachment =
        disposition.toLowerCase().contains('attachment') ||
        (looksLikeDownloadUrl(uri.toString()) &&
            (mime == null || !mime.startsWith('text/html')));
    int? total = response?.contentLength;
    if ((total == null || total <= 0) && response?.contentRange != null) {
      final RegExpMatch? match = RegExp(r'/(\d+)$')
          .firstMatch(response!.contentRange!);
      total = int.tryParse(match?.group(1) ?? '');
    }
    return DownloadProbeResult(
      url: uri.toString(),
      fileName: name,
      attachment: attachment,
      mimeType: mime,
      totalBytes: total != null && total > 0 ? total : null,
      contentDisposition: disposition.isEmpty ? null : disposition,
      statusCode: response?.statusCode,
      authChallenge: response?.authChallenge,
      nameKnown: dispositionName.isNotEmpty || fallbackNameWasMeaningful(uri),
    );
  }

  static bool fallbackNameWasMeaningful(Uri uri) {
    final String raw = uri.path.split('/').last;
    return raw.isNotEmpty && raw.toLowerCase() != 'download';
  }

  static String? _cleanMime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.split(';').first.trim().toLowerCase();
  }

  static bool _isPrivateHost(String host) {
    if (host == 'localhost' || host.endsWith('.local')) {
      return true;
    }
    final InternetAddress? address = InternetAddress.tryParse(host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return false;
    }
    final List<int> bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        bytes[0] == 127;
  }
}

class _ProbeHeaders {
  const _ProbeHeaders({
    required this.statusCode,
    required this.contentDisposition,
    required this.contentType,
    required this.contentLength,
    required this.contentRange,
    required this.authChallenge,
  });

  final int statusCode;
  final String? contentDisposition;
  final String? contentType;
  final int? contentLength;
  final String? contentRange;
  final String? authChallenge;
}
