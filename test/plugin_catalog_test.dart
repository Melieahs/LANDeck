import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/native/native_module_registry.dart';
import 'package:landeck/native/plugin/imported_module_store.dart';
import 'package:landeck/native/plugin/plugin_catalog.dart';
import 'package:landeck/native/plugin/plugin_manifest.dart';

void main() {
  late HttpServer server;
  late Uri indexUri;
  late Directory temp;
  late Map<String, (int, String)> responses;
  late PluginCatalog catalog;

  setUp(() async {
    responses = <String, (int, String)>{};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    indexUri = Uri.parse(
      'http://127.0.0.1:${server.port}/examples/native-modules/index.json',
    );
    catalog = PluginCatalog(
      indexUri: indexUri,
      timeout: const Duration(seconds: 3),
    );
    server.listen((HttpRequest request) async {
      final (int, String)? match = responses[request.uri.path];
      request.response.statusCode = match?.$1 ?? HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(match?.$2 ?? 'not found');
      await request.response.close();
    });
    temp = await Directory.systemTemp.createTemp('landeck-plugin-catalog');
    NativeModuleRegistry.instance.resetToDefaults();
  });

  tearDown(() async {
    NativeModuleRegistry.instance.resetToDefaults();
    await server.close(force: true);
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('fetch parses the repository index', () async {
    responses['/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      File('examples/native-modules/index.json').readAsStringSync(),
    );

    final List<PluginCatalogEntry> entries = await catalog.fetch();

    expect(entries, hasLength(1));
    expect(entries.single.id, 'plugin.padavan-wan');
    expect(entries.single.name, 'Padavan 路由器');
    expect(entries.single.version, '1.0.0');
    expect(entries.single.path, 'padavan-wan/plugin.json');
  });

  test('download validates and installs the manifest', () async {
    responses['/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      File('examples/native-modules/index.json').readAsStringSync(),
    );
    responses['/examples/native-modules/padavan-wan/plugin.json'] = (
      HttpStatus.ok,
      File('examples/native-modules/padavan-wan/plugin.json')
          .readAsStringSync(),
    );

    final List<PluginCatalogEntry> entries = await catalog.fetch();
    final ImportedNativeModule module = await catalog.download(entries.single);

    expect(module.id, 'plugin.padavan-wan');
    expect(module.manifest.fields, hasLength(8));
    expect(module.manifest.actions, hasLength(3));

    final ImportedPluginResult result = await ImportedPluginStore(
      directory: temp,
    ).install(module);

    expect(result.replaced, isFalse);
    expect(File('${temp.path}/plugin.padavan-wan.json').existsSync(), isTrue);
    expect(NativeModuleRegistry.instance.byId('plugin.padavan-wan'), isNotNull);
  });

  test('falls back to the mirror index and downloads from it', () async {
    final Uri fallback = Uri.parse(
      'http://127.0.0.1:${server.port}/mirror/examples/native-modules/index.json',
    );
    final PluginCatalog withFallback = PluginCatalog(
      indexUri: indexUri,
      fallbackIndexUri: fallback,
      timeout: const Duration(seconds: 3),
    );
    responses['/mirror/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      File('examples/native-modules/index.json').readAsStringSync(),
    );
    responses['/mirror/examples/native-modules/padavan-wan/plugin.json'] = (
      HttpStatus.ok,
      File('examples/native-modules/padavan-wan/plugin.json')
          .readAsStringSync(),
    );

    final List<PluginCatalogEntry> entries = await withFallback.fetch();

    expect(entries.single.baseUri, fallback);
    final ImportedNativeModule module = await withFallback.download(
      entries.single,
    );
    expect(module.id, 'plugin.padavan-wan');
  });

  test('fetch rejects unsafe paths', () async {
    responses['/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'plugins': <Object?>[
          <String, Object?>{
            'id': 'plugin.evil',
            'name': 'Evil',
            'version': '1.0.0',
            'description': 'traversal',
            'path': '../evil.json',
          },
        ],
      }),
    );

    await expectLater(catalog.fetch(), throwsA(isA<PluginCatalogException>()));
  });

  test('fetch rejects duplicate ids and bad schema versions', () async {
    responses['/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'plugins': <Object?>[
          <String, Object?>{
            'id': 'plugin.dup',
            'name': 'A',
            'version': '1.0.0',
            'description': 'first',
            'path': 'a/plugin.json',
          },
          <String, Object?>{
            'id': 'plugin.dup',
            'name': 'B',
            'version': '1.0.0',
            'description': 'second',
            'path': 'b/plugin.json',
          },
        ],
      }),
    );
    await expectLater(catalog.fetch(), throwsA(isA<PluginCatalogException>()));

    responses['/examples/native-modules/index.json'] = (
      HttpStatus.ok,
      jsonEncode(<String, Object?>{'schemaVersion': 2, 'plugins': <Object?>[]}),
    );
    await expectLater(catalog.fetch(), throwsA(isA<PluginCatalogException>()));
  });

  test('reports http failures', () async {
    await expectLater(
      catalog.fetch(),
      throwsA(
        isA<PluginCatalogException>().having(
          (PluginCatalogException error) => error.message,
          'message',
          contains('HTTP 404'),
        ),
      ),
    );
  });
}
