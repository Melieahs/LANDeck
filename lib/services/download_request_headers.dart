import 'dart:convert';

import '../models/http_credential.dart';
import '../models/service.dart';
import 'http_credential_store.dart';

/// Builds the headers a download should inherit from the current WebView
/// session. Secrets stay in memory and are passed only to the local Android
/// foreground service; they are never written to the database or logs.
class DownloadRequestHeaders {
  const DownloadRequestHeaders._();

  static Future<Map<String, String>> build({
    required Service service,
    required String url,
    HttpCredential? sessionCredential,
  }) async {
    final Map<String, String> headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Version/4.0 Chrome/120 Mobile Safari/537.36 '
          'LANDeck/0.7',
      'Accept': '*/*',
    };
    final Uri? uri = Uri.tryParse(url);
    final String host = _normalizeHost(uri?.host ?? '');

    // webview_flutter 4.10 (used by the Catalina build) has no cookie read
    // API. Downloads still work, just without the WebView session cookies;
    // the current SDK build keeps the full behaviour.

    HttpCredential? credential = sessionCredential;
    if (credential == null || !credential.matches(host, credential.realm)) {
      final List<HttpCredential> stored = await HttpCredentialStore.instance
          .credentialsFor(service.id);
      for (final HttpCredential item in stored) {
        if (item.matches(host, item.realm)) {
          credential = item;
        }
      }
    }
    if (credential != null &&
        credential.matches(host, credential.realm) &&
        host.isNotEmpty) {
      final String token = base64Encode(
        utf8.encode('${credential.username}:${credential.password}'),
      );
      headers['Authorization'] = 'Basic $token';
    }

    if (service.url.isNotEmpty) {
      headers['Referer'] = service.url;
    }
    return headers;
  }

  static String _normalizeHost(String host) =>
      host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
}
