import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/http_credential.dart';
import 'package:landeck/services/http_credential_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  HttpCredential credential({
    String serviceId = 'service-1',
    String host = '192.168.1.1',
    String realm = 'Padavan',
    String username = 'admin',
    String password = 'secret',
    DateTime? updatedAt,
  }) {
    return HttpCredential(
      serviceId: serviceId,
      host: host,
      realm: realm,
      username: username,
      password: password,
      updatedAt: updatedAt ?? DateTime(2026, 11, 20, 12),
    );
  }

  test('credential matches host case-insensitively and realm exactly', () {
    final HttpCredential value = credential(host: 'NAS.local');
    expect(value.matches('nas.local', 'Padavan'), isTrue);
    expect(value.matches('nas.local.', 'Padavan'), isTrue);
    expect(value.matches('nas.local', 'Other realm'), isFalse);
    expect(value.matches('other.local', 'Padavan'), isFalse);
  });

  test('credential serialization keeps password out of toString', () {
    final HttpCredential value = credential();
    final HttpCredential decoded = HttpCredential.fromJson(value.toJson());
    expect(decoded.username, 'admin');
    expect(decoded.password, 'secret');
    expect(decoded.host, '192.168.1.1');
    expect(decoded.realm, 'Padavan');
    expect(value.toString(), isNot(contains('secret')));
  });

  test('store keeps credentials bound to service, host and realm', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential());
    await store.save(credential(realm: 'Other', username: 'second'));
    await store.save(credential(serviceId: 'service-2', host: '10.0.0.2'));

    expect(
      (await store.find('service-1', host: '192.168.1.1', realm: 'Padavan'))
          ?.username,
      'admin',
    );
    expect(
      (await store.find('service-1', host: '192.168.1.1', realm: 'Other'))
          ?.username,
      'second',
    );
    expect(
      await store.find('service-1', host: '192.168.1.2', realm: 'Padavan'),
      isNull,
    );
    expect(
      await store.find('service-2', host: '10.0.0.2', realm: 'Padavan'),
      isNotNull,
    );
  });

  test('store can delete one scope and all service credentials', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential());
    await store.save(credential(realm: 'Other', username: 'second'));

    await store.deleteScope(
      'service-1',
      host: '192.168.1.1',
      realm: 'Padavan',
    );
    expect(
      await store.find('service-1', host: '192.168.1.1', realm: 'Padavan'),
      isNull,
    );
    expect(
      await store.find('service-1', host: '192.168.1.1', realm: 'Other'),
      isNotNull,
    );

    await store.deleteAll('service-1');
    expect(await store.credentialsFor('service-1'), isEmpty);
  });
}
