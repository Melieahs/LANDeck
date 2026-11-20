import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/core/utils/html_utils.dart';
import 'package:landeck/core/utils/network_utils.dart';
import 'package:landeck/core/utils/url_utils.dart';

void main() {
  test('normalizes LAN URLs with IP, port, path and query', () {
    expect(
      normalizeHttpUrl('192.168.1.10:8080/docker?x=1'),
      'http://192.168.1.10:8080/docker?x=1',
    );
    expect(normalizeHttpUrl('https://nas.local/app'), 'https://nas.local/app');
    expect(normalizeHttpUrl('ftp://nas.local'), isNull);
    expect(normalizeHttpUrl(''), isNull);
  });

  test('canonical URL deduplicates default ports and trailing slash', () {
    expect(
      canonicalHttpUrl('http://nas.local:80/'),
      canonicalHttpUrl('http://nas.local'),
    );
    expect(
      canonicalHttpUrl('https://nas.local:443/ui/'),
      canonicalHttpUrl('https://nas.local/ui/'),
    );
  });

  test('extracts HTML titles without external packages', () {
    expect(
      extractHtmlTitle('<html><head><title> 飞牛 &amp; OS </title></head>'),
      '飞牛 & OS',
    );
    expect(extractHtmlTitle('<html><body>none</body></html>'), isNull);
  });

  test('composes device-centric service URLs', () {
    expect(
      buildServiceUrl(
        address: '192.168.1.10',
        protocol: 'http',
        port: 8096,
        path: '/web',
      ),
      'http://192.168.1.10:8096/web',
    );
    expect(
      buildServiceUrl(
        address: 'nas.local',
        protocol: 'https',
        port: 443,
        path: '/',
      ),
      'https://nas.local',
    );
    expect(
      buildServiceUrl(
        customUrl: 'https://proxy.example.com/jellyfin',
        address: '192.168.1.10',
        protocol: 'http',
        port: 8096,
      ),
      'https://proxy.example.com/jellyfin',
    );
    expect(
      buildServiceUrl(
        address: '192.168.1.10',
        protocol: 'http',
        port: 5666,
        path: 'files?sort=name',
      ),
      'http://192.168.1.10:5666/files?sort=name',
    );
  });

  test('subnet helpers reject unsafe ranges', () {
    expect(prefixFromSubnetMask('255.255.255.0'), 24);
    expect(hostsForCidr('192.168.1.2', 24).length, 254);
    expect(cidrLabel('192.168.1.2', 24), '192.168.1.2/24');
  });
}
