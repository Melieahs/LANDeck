/// A credential for HTTP authentication, bound to one service and one
/// authentication scope (host + realm).
///
/// Passwords are only persisted by [HttpCredentialStore] through Android
/// Keystore-backed secure storage. This model intentionally keeps [password]
/// out of `toString` so it cannot leak into logs by accident.
class HttpCredential {
  const HttpCredential({
    required this.serviceId,
    required this.host,
    required this.realm,
    required this.username,
    required this.password,
    required this.updatedAt,
  });

  final String serviceId;
  final String host;
  final String realm;
  final String username;
  final String password;
  final DateTime updatedAt;

  String get normalizedHost =>
      host.toLowerCase().replaceAll(RegExp(r'\.$'), '');

  /// Scopes are compared case-insensitively by host and exactly by realm.
  bool matches(String candidateHost, String candidateRealm) {
    return normalizedHost ==
            candidateHost.toLowerCase().replaceAll(RegExp(r'\.$'), '') &&
        realm == candidateRealm;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'serviceId': serviceId,
    'host': host,
    'realm': realm,
    'username': username,
    'password': password,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory HttpCredential.fromJson(Map<String, Object?> json) {
    return HttpCredential(
      serviceId: json['serviceId'] as String? ?? '',
      host: json['host'] as String? ?? '',
      realm: json['realm'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  String toString() =>
      'HttpCredential(serviceId: $serviceId, host: $host, realm: $realm, '
      'username: $username)';
}
