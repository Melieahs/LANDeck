import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:landeck/native/padavan/padavan_client.dart';
import 'package:flutter_test/flutter_test.dart';

const String _statusHtml = '''
function wanlink_status() { return 0;}
function wanlink_etherlink() { return '';}
function wanlink_apclilink() { return 'BSSID: D4:25:DE:D9:36:39';}
function wanlink_uptime() { return 2501;}
function wanlink_dltime() { return 6499;}
function wanlink_type() { return 'Automatic IP';}
function wanlink_ip4_wan() { return '172.18.77.35';}
function wanlink_gw4_wan() { return '172.18.72.1';}
function wanlink_dns() { return '10.0.0.1';}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses the same wanlink functions used by the Padavan page', () {
    final PadavanStatus? status = PadavanStatus.tryParse(_statusHtml);
    expect(status, isNotNull);
    expect(status!.connected, isTrue);
    expect(status.stateLabel, '已连接');
    expect(status.type, 'Automatic IP');
    expect(status.wanIp, '172.18.77.35');
    expect(status.gateway, '172.18.72.1');
    expect(status.dns, '10.0.0.1');
    expect(status.uptimeSeconds, 2501);
    expect(status.apCliLink, 'BSSID: D4:25:DE:D9:36:39');
  });

  test('POSTs the exact form and parses the reload delay', () async {
    late http.Request captured;
    final PadavanClient client = PadavanClient(
      baseUri: Uri.parse('http://192.168.1.1/'),
      username: 'u',
      password: 'p',
      client: MockClient((http.Request request) async {
        captured = request;
        return http.Response(
          '<script>restart_needed_time(5);</script>',
          200,
          headers: <String, String>{'content-type': 'text/html'},
        );
      }),
    );

    final PadavanActionResult result = await client.perform(
      PadavanClient.wanReconnect,
    );
    expect(result.reloadSeconds, 5);
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://192.168.1.1/device-map/wan_action.asp');
    expect(captured.headers['authorization'], startsWith('Basic '));
    expect(
      captured.headers['content-type'],
      'application/x-www-form-urlencoded',
    );
    expect(captured.body, contains('wan_action=Connect'));
    expect(captured.body, contains('modem_prio=0'));
  });

  test('surfaces the Basic realm on 401', () async {
    final PadavanClient client = PadavanClient(
      baseUri: Uri.parse('http://192.168.1.1/'),
      username: 'bad',
      password: 'bad',
      client: MockClient((http.Request request) async {
        return http.Response(
          '401',
          401,
          headers: <String, String>{
            'www-authenticate': 'Basic realm="CR660x"',
          },
        );
      }),
    );

    await expectLater(
      client.fetchStatus(),
      throwsA(
        isA<PadavanAuthException>().having(
          (PadavanAuthException error) => error.realm,
          'realm',
          'CR660x',
        ),
      ),
    );
  });

  test('detects the router login-conflict page as an auth failure', () async {
    final PadavanClient client = PadavanClient(
      baseUri: Uri.parse('http://192.168.1.1/'),
      username: 'u',
      password: 'p',
      client: MockClient((http.Request request) async {
        return http.Response.bytes(
          utf8.encode(
            '<p>已登录用户 IP: 192.168.1.39</p><p>请先注销另一用户后再尝试登录。</p>',
          ),
          200,
        );
      }),
    );

    await expectLater(
      client.perform(PadavanClient.wanDisconnect),
      throwsA(isA<PadavanAuthException>()),
    );
  });
}
