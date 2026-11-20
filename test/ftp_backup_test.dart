import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/services/ftp_backup_service.dart';

void main() {
  test('FTP config round-trips without losing fields', () {
    const FtpConfig config = FtpConfig(
      host: 'nas.local',
      port: 2121,
      username: 'landeck',
      password: 'secret',
      remoteDirectory: '/backups/landeck',
      fileName: 'devices.json',
      security: FtpSecurity.ftpes,
    );
    final FtpConfig restored = FtpConfig.fromJson(config.toJson());
    expect(restored.host, 'nas.local');
    expect(restored.port, 2121);
    expect(restored.username, 'landeck');
    expect(restored.password, 'secret');
    expect(restored.remoteDirectory, '/backups/landeck');
    expect(restored.fileName, 'devices.json');
    expect(restored.security, FtpSecurity.ftpes);
    expect(restored.normalizedDirectory, '/backups/landeck');
  });

  test('FTP settings persist in secure storage', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    const FtpSettingsStore store = FtpSettingsStore();
    const FtpConfig config = FtpConfig(
      host: '192.168.1.10',
      username: 'admin',
      password: 'pass',
      remoteDirectory: '/',
    );
    await store.save(config);
    final FtpConfig loaded = await store.load();
    expect(loaded.host, '192.168.1.10');
    expect(loaded.username, 'admin');
    expect(loaded.password, 'pass');
    await store.clear();
    expect((await store.load()).host, isEmpty);
  });

  test('invalid FTP config is rejected before connecting', () async {
    const FtpBackupService service = FtpBackupService();
    expect(
      () => service.testConnection(const FtpConfig()),
      throwsA(isA<FtpBackupException>()),
    );
  });
}
