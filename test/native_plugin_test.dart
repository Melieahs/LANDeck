import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/models/service.dart';
import 'package:landeck/native/native_module_registry.dart';
import 'package:landeck/native/plugin/imported_module_store.dart';
import 'package:landeck/native/plugin/plugin_manifest.dart';

const Map<String, Object?> sample = <String, Object?>{
  'schemaVersion': 1,
  'id': 'plugin.demo-status',
  'name': '演示状态',
  'version': '1.0.0',
  'description': '读取 JSON 状态',
  'match': <String, Object?>{
    'hostPatterns': <String>['192.168.1.*'],
    'ports': <int>[8080],
  },
  'basicAuth': true,
  'status': <String, Object?>{
    'method': 'GET',
    'path': '/api/status',
    'fields': <Object?>[
      <String, Object?>{'label': '状态', 'path': 'state', 'map': <String, String>{'up': '在线'}},
    ],
  },
  'actions': <Object?>[
    <String, Object?>{
      'id': 'restart',
      'label': '重启',
      'icon': 'restart',
      'confirmText': '确认重启？',
      'refreshDelaySeconds': 2,
      'request': <String, Object?>{
        'method': 'POST',
        'path': '/api/restart',
        'form': <String, String>{'action': 'restart'},
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manifest parses declarative status and actions', () {
    final PluginManifest manifest = PluginManifest.parse(sample);
    expect(manifest.id, 'plugin.demo-status');
    expect(manifest.basicAuth, isTrue);
    expect(manifest.fields.single.label, '状态');
    expect(manifest.actions.single.confirmText, '确认重启？');
    expect(manifest.status!.resolve(Uri.parse('http://192.168.1.2:8080')).path, '/api/status');
  });

  test('manifest rejects unsafe ids and absolute request URLs', () {
    expect(
      () => PluginManifest.parse(<String, Object?>{...sample, 'id': 'builtin.fake'}),
      throwsA(isA<PluginManifestException>()),
    );
    expect(
      () => PluginManifest.parse(<String, Object?>{
        ...sample,
        'actions': <Object?>[
          <String, Object?>{
            'id': 'bad',
            'label': 'bad',
            'request': <String, Object?>{'method': 'POST', 'path': 'http://evil.example/x'},
          },
        ],
      }),
      throwsA(isA<PluginManifestException>()),
    );
  });

  test('match uses host glob and port', () {
    final PluginManifest manifest = PluginManifest.parse(sample);
    final Service service = Service(
      id: 's1',
      name: 'Demo',
      protocol: 'http',
      port: 8080,
      customUrl: 'http://192.168.1.2:8080/',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(manifest.match!.matches(service), isTrue);
    final Service other = service.copyWith(customUrl: () => 'http://10.0.0.2:8080/');
    expect(manifest.match!.matches(other), isFalse);
  });

  test('store installs, loads and deletes an imported module', () async {
    final Directory dir = await Directory.systemTemp.createTemp('landeck_plugin_test');
    addTearDown(() async {
      NativeModuleRegistry.instance.resetToDefaults();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final ImportedPluginStore store = ImportedPluginStore(directory: dir);
    final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonEncode(sample)));
    final ImportedNativeModule preview = await store.previewBytes(bytes);
    expect(preview.isBuiltin, isFalse);
    final ImportedPluginResult result = await store.install(preview);
    expect(result.replaced, isFalse);
    expect(File('${dir.path}/plugin.demo-status.json').existsSync(), isTrue);
    expect(await store.loadAll(), hasLength(1));
    expect(NativeModuleRegistry.instance.byId('plugin.demo-status'), isNotNull);
    await store.delete('plugin.demo-status');
    expect(NativeModuleRegistry.instance.byId('plugin.demo-status'), isNull);
    expect(await store.loadAll(), isEmpty);
  });

  test('store accepts a zip package with plugin.json', () async {
    final Directory dir = await Directory.systemTemp.createTemp('landeck_plugin_zip_test');
    addTearDown(() async {
      NativeModuleRegistry.instance.resetToDefaults();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final Archive archive = Archive()
      ..addFile(ArchiveFile.string('module/plugin.json', jsonEncode(sample)));
    final Uint8List zip = ZipEncoder().encodeBytes(archive);
    final ImportedPluginStore store = ImportedPluginStore(directory: dir);
    final ImportedNativeModule preview = await store.previewBytes(zip, fileName: 'demo.zip');
    expect(preview.id, 'plugin.demo-status');
    expect(preview.manifest.status, isNotNull);
  });
}
