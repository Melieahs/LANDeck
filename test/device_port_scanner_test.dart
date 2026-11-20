import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/services/device_port_scanner.dart';

void main() {
  test(
    'phase 2 scanner confirms a real HTTP service and flags a bare port',
    () async {
      final HttpServer http = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      http.listen((HttpRequest request) async {
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<html><title>LANDeck test service</title></html>',
        );
        await request.response.close();
      });

      final ServerSocket bare = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      bare.listen((Socket socket) => socket.destroy());

      final DevicePortScanner scanner = DevicePortScanner();
      final DevicePortScanReport report = await scanner.scan(
        '127.0.0.1',
        ports: <int>[http.port, bare.port],
        onProgress: (_) {},
      );

      final DevicePortResult web = report.results.firstWhere(
        (DevicePortResult result) => result.port == http.port,
      );
      expect(web.category, PortScanCategory.confirmedHttp);
      expect(web.statusCode, 200);
      expect(web.title, 'LANDeck test service');
      expect(web.url, 'http://127.0.0.1:${http.port}');

      final DevicePortResult open = report.results.firstWhere(
        (DevicePortResult result) => result.port == bare.port,
      );
      expect(open.category, PortScanCategory.openPort);
      expect(open.isWeb, isFalse);

      await http.close(force: true);
      await bare.close();
    },
  );
}
