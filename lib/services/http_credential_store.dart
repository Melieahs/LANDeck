import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/http_credential.dart';

/// Persists HTTP authentication credentials per service.
///
/// Data is stored as one encrypted value per service. Android uses the
/// Keystore-backed AES-GCM implementation provided by flutter_secure_storage.
/// Credentials are never stored in Sembast, shared preferences, URLs, or logs.
class HttpCredentialStore {
  HttpCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'landeck_http_auth'),
          );

  static final HttpCredentialStore instance = HttpCredentialStore();

  static const String _keyPrefix = 'landeck.httpAuth.v1.';

  final FlutterSecureStorage _storage;

  String _keyFor(String serviceId) => '$_keyPrefix$serviceId';

  Future<List<HttpCredential>> credentialsFor(String serviceId) async {
    if (serviceId.isEmpty) {
      return const <HttpCredential>[];
    }
    try {
      final String? raw = await _storage.read(key: _keyFor(serviceId));
      if (raw == null || raw.isEmpty) {
        return const <HttpCredential>[];
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <HttpCredential>[];
      }
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> value) => HttpCredential.fromJson(
              value.map(
                (Object? key, Object? item) => MapEntry(key.toString(), item),
              ),
            ),
          )
          .where(
            (HttpCredential credential) => credential.serviceId == serviceId,
          )
          .toList(growable: false);
    } on Object {
      // A secure-storage failure must not break the WebView. Treat it as
      // "no saved credentials" and let the user authenticate manually.
      return const <HttpCredential>[];
    }
  }

  Future<HttpCredential?> find(
    String serviceId, {
    required String host,
    required String realm,
  }) async {
    final List<HttpCredential> credentials = await credentialsFor(serviceId);
    for (final HttpCredential credential in credentials) {
      if (credential.matches(host, realm)) {
        return credential;
      }
    }
    return null;
  }

  Future<void> save(HttpCredential credential) async {
    final List<HttpCredential> credentials = List<HttpCredential>.of(
      await credentialsFor(credential.serviceId),
    );
    credentials.removeWhere(
      (HttpCredential existing) =>
          existing.matches(credential.host, credential.realm),
    );
    credentials.add(credential);
    await _write(credential.serviceId, credentials);
  }

  Future<void> deleteScope(
    String serviceId, {
    required String host,
    required String realm,
  }) async {
    final List<HttpCredential> credentials = List<HttpCredential>.of(
      await credentialsFor(serviceId),
    );
    credentials.removeWhere(
      (HttpCredential existing) => existing.matches(host, realm),
    );
    if (credentials.isEmpty) {
      await _storage.delete(key: _keyFor(serviceId));
      return;
    }
    await _write(serviceId, credentials);
  }

  Future<void> deleteAll(String serviceId) async {
    await _storage.delete(key: _keyFor(serviceId));
  }

  Future<void> _write(
    String serviceId,
    List<HttpCredential> credentials,
  ) async {
    await _storage.write(
      key: _keyFor(serviceId),
      value: jsonEncode(
        credentials
            .map((HttpCredential credential) => credential.toJson())
            .toList(growable: false),
      ),
    );
  }
}
