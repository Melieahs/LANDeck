import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ftpconnect/ftpconnect.dart';

enum FtpSecurity { ftp, ftpes, ftps }

extension FtpSecurityLabel on FtpSecurity {
  String get label => switch (this) {
    FtpSecurity.ftp => 'FTP',
    FtpSecurity.ftpes => 'FTPES（显式 TLS）',
    FtpSecurity.ftps => 'FTPS（隐式 TLS）',
  };

  SecurityType get native => switch (this) {
    FtpSecurity.ftp => SecurityType.ftp,
    FtpSecurity.ftpes => SecurityType.ftpes,
    FtpSecurity.ftps => SecurityType.ftps,
  };
}

class FtpConfig {
  const FtpConfig({
    this.host = '',
    this.port = 21,
    this.username = '',
    this.password = '',
    this.remoteDirectory = '/',
    this.fileName = 'landeck-backup.json',
    this.security = FtpSecurity.ftp,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String remoteDirectory;
  final String fileName;
  final FtpSecurity security;

  bool get isValid =>
      host.trim().isNotEmpty &&
      port > 0 &&
      port <= 65535 &&
      fileName.trim().isNotEmpty;

  String get normalizedDirectory {
    final String value = remoteDirectory.trim();
    if (value.isEmpty || value == '/') {
      return '/';
    }
    return value.startsWith('/') ? value : '/$value';
  }

  FtpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? remoteDirectory,
    String? fileName,
    FtpSecurity? security,
  }) {
    return FtpConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      remoteDirectory: remoteDirectory ?? this.remoteDirectory,
      fileName: fileName ?? this.fileName,
      security: security ?? this.security,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'remoteDirectory': remoteDirectory,
    'fileName': fileName,
    'security': security.name,
  };

  factory FtpConfig.fromJson(Map<String, Object?> json) {
    final String securityName = json['security'] as String? ?? 'ftp';
    return FtpConfig(
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 21,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      remoteDirectory: json['remoteDirectory'] as String? ?? '/',
      fileName: json['fileName'] as String? ?? 'landeck-backup.json',
      security: FtpSecurity.values.firstWhere(
        (FtpSecurity value) => value.name == securityName,
        orElse: () => FtpSecurity.ftp,
      ),
    );
  }
}

class FtpSettingsStore {
  const FtpSettingsStore();

  static const String _key = 'landeck.ftp.v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<FtpConfig> load() async {
    try {
      final String? raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return const FtpConfig();
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return FtpConfig.fromJson(Map<String, Object?>.from(decoded));
      }
    } on Object {
      // A broken secure-storage entry must not block the settings page.
    }
    return const FtpConfig();
  }

  Future<void> save(FtpConfig config) {
    return _storage.write(key: _key, value: jsonEncode(config.toJson()));
  }

  Future<void> clear() => _storage.delete(key: _key);
}

class FtpBackupException implements Exception {
  const FtpBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FtpBackupService {
  const FtpBackupService();

  Future<void> testConnection(FtpConfig config) async {
    await _withClient<void>(config, (FTPConnect client) async {});
  }

  Future<void> uploadBackup(
    FtpConfig config,
    Map<String, Object?> snapshot,
  ) async {
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(snapshot)),
    );
    await _withClient<void>(config, (FTPConnect client) async {
      final bool uploaded = await client.uploadData(
        bytes,
        config.fileName.trim(),
      );
      if (!uploaded) {
        throw const FtpBackupException('FTP 服务器没有接受备份文件');
      }
    });
  }

  Future<Map<String, Object?>> downloadBackup(FtpConfig config) async {
    return _withClient<Map<String, Object?>>(config, (FTPConnect client) async {
      final Uint8List bytes = await client.downloadToBytes(
        config.fileName.trim(),
      );
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FtpBackupException('备份文件不是有效的 JSON 对象');
      }
      return Map<String, Object?>.from(decoded);
    });
  }

  Future<T> _withClient<T>(
    FtpConfig config,
    Future<T> Function(FTPConnect client) action,
  ) async {
    if (!config.isValid) {
      throw const FtpBackupException('请填写 FTP 地址、端口和备份文件名');
    }
    final FTPConnect client = FTPConnect(
      config.host.trim(),
      port: config.port,
      user: config.username.trim(),
      pass: config.password,
      securityType: config.security.native,
      timeout: 15,
      showLog: false,
    );
    try {
      final bool connected = await client.connect();
      if (!connected) {
        throw const FtpBackupException('无法连接 FTP 服务器');
      }
      if (config.normalizedDirectory != '/') {
        final String directory = config.normalizedDirectory;
        final String relative = directory.replaceFirst(RegExp(r'^/+'), '');
        bool changed = false;
        for (final String candidate in <String>{
          directory,
          '$directory/',
          if (relative.isNotEmpty) relative,
          if (relative.isNotEmpty) '$relative/',
        }) {
          if (await client.changeDirectory(candidate)) {
            changed = true;
            break;
          }
        }
        if (!changed) {
          String current = '/';
          String rootEntries = '';
          try {
            current = await client.currentDirectory();
            final List<FTPEntry> entries = await client.listDirectoryContent();
            rootEntries = entries
                .take(10)
                .map((FTPEntry entry) => entry.name)
                .where((String name) => name.isNotEmpty)
                .join('、');
          } on Object {
            // The diagnostic is best effort; the directory error is primary.
          }
          throw FtpBackupException(
            'FTP 拒绝进入 $directory（当前目录：$current）'
            '${rootEntries.isEmpty ? '' : '；根目录包含：$rootEntries'}。'
            '如果登录后根目录就是目标目录，请把远程目录填 /。',
          );
        }
      }
      return await action(client);
    } on FtpBackupException {
      rethrow;
    } on Object catch (error) {
      throw FtpBackupException('FTP 操作失败：$error');
    } finally {
      try {
        await client.disconnect();
      } on Object {
        // The operation result is more useful than a disconnect error.
      }
    }
  }
}
