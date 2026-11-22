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
      (await store.find(
        'service-1',
        host: '192.168.1.1',
        realm: 'Padavan',
      ))?.username,
      'admin',
    );
    expect(
      (await store.find(
        'service-1',
        host: '192.168.1.1',
        realm: 'Other',
      ))?.username,
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

  test('store keeps separate accounts for different ports', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential(host: '192.168.1.12:5666', username: 'fnos'));
    await store.save(
      credential(host: '192.168.1.12:8096', username: 'jellyfin'),
    );

    expect(
      (await store.find(
        'service-1',
        host: '192.168.1.12:5666',
        realm: 'Padavan',
      ))?.username,
      'fnos',
    );
    expect(
      (await store.find(
        'service-1',
        host: '192.168.1.12:8096',
        realm: 'Padavan',
      ))?.username,
      'jellyfin',
    );
    expect(
      (await store.find('service-1', host: '192.168.1.12', realm: 'Padavan')),
      isNull,
    );
  });

  test('store keeps multiple accounts for the same scope', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential(username: 'alice', password: 'one'));
    await store.save(credential(username: 'bob', password: 'two'));
    final List<HttpCredential> accounts = await store.accountsFor(
      'service-1',
      host: '192.168.1.1',
      realm: 'Padavan',
    );
    expect(
      accounts.map((HttpCredential item) => item.username),
      <String>['bob', 'alice'],
    );
    expect(
      (await store.find(
        'service-1',
        host: '192.168.1.1',
        realm: 'Padavan',
        preferUsername: 'alice',
      ))?.password,
      'one',
    );
  });

  test('store overwrites the same account and deletes one account', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential(username: 'alice', password: 'old'));
    await store.save(credential(username: 'bob', password: 'two'));
    await store.save(credential(username: 'alice', password: 'new'));

    final List<HttpCredential> afterSave = await store.accountsFor(
      'service-1',
      host: '192.168.1.1',
      realm: 'Padavan',
    );
    expect(afterSave.length, 2);
    expect(
      afterSave.singleWhere(
        (HttpCredential item) => item.username == 'alice',
      ).password,
      'new',
    );

    await store.deleteCredential(
      'service-1',
      host: '192.168.1.1',
      realm: 'Padavan',
      username: 'alice',
    );
    final List<HttpCredential> afterDelete = await store.accountsFor(
      'service-1',
      host: '192.168.1.1',
      realm: 'Padavan',
    );
    expect(
      afterDelete.map((HttpCredential item) => item.username),
      <String>['bob'],
    );
  });

  test('store can delete one scope and all service credentials', () async {
    final HttpCredentialStore store = HttpCredentialStore();
    await store.save(credential());
    await store.save(credential(realm: 'Other', username: 'second'));

    await store.deleteScope('service-1', host: '192.168.1.1', realm: 'Padavan');
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
