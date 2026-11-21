import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/http_credential.dart';
import 'package:landeck/services/web_password_fill.dart';

void main() {
  group('WebPasswordFill', () {
    test('extracts normalized hosts', () {
      expect(
        WebPasswordFill.hostOf('http://192.168.1.10:8096/web'),
        '192.168.1.10',
      );
      expect(WebPasswordFill.hostOf('https://NAS.local/'), 'nas.local');
      expect(WebPasswordFill.hostOf('not a url'), isNull);
    });

    test('scopes credentials to host and non-default port', () {
      expect(
        WebPasswordFill.scopeHostOf(Uri.parse('http://192.168.1.2/')),
        '192.168.1.2',
      );
      expect(
        WebPasswordFill.scopeHostOf(Uri.parse('http://192.168.1.12:5666/')),
        '192.168.1.12:5666',
      );
      expect(
        WebPasswordFill.scopeHostOf(Uri.parse('https://nas.local:443/')),
        'nas.local',
      );
      expect(
        WebPasswordFill.scopeHostOf(Uri.parse('https://nas.local:8443/')),
        'nas.local:8443',
      );
    });

    test('serializes capture/fill with the full origin', () {
      expect(WebPasswordFill.hookScript, contains('location.host'));
      expect(WebPasswordFill.captureScript, contains('location.host'));
    });

    test('serializes fill values safely', () {
      final String script = WebPasswordFill.fillScript(
        username: 'ad"min\\',
        password: 'p@ss"\nword',
      );
      expect(script, contains(jsonEncode('ad"min\\')));
      expect(script, contains(jsonEncode('p@ss"\nword')));
      expect(script, contains('input[type="password"]'));
      expect(script, contains('dispatchEvent'));
    });

    test('decodes map, JSON string and double-encoded results', () {
      expect(
        WebPasswordFill.decodeResult(<String, Object?>{'ok': true})?['ok'],
        true,
      );
      expect(
        WebPasswordFill.decodeResult('{"ok":true,"username":"a"}')?['username'],
        'a',
      );
      expect(
        WebPasswordFill.decodeResult(
          jsonEncode(jsonEncode(<String, Object?>{'ok': true})),
        )?['ok'],
        true,
      );
      expect(WebPasswordFill.decodeResult('broken'), isNull);
    });

    test('labels web-form credentials', () {
      final HttpCredential credential = HttpCredential(
        serviceId: 's',
        host: 'nas.local',
        realm: WebPasswordFill.webRealm,
        username: 'admin',
        password: 'secret',
        updatedAt: DateTime(2026),
      );
      expect(credential.scopeLabel, '网页登录');
      expect(credential.toString(), isNot(contains('secret')));
    });
  });
}
