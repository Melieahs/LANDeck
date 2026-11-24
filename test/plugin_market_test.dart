import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:landeck/native/native_module_registry.dart';
import 'package:landeck/native/plugin/imported_module_store.dart';
import 'package:landeck/native/plugin/plugin_catalog.dart';
import 'package:landeck/native/plugin/plugin_manifest.dart';
import 'package:landeck/pages/discover/plugin_market_section.dart';
import 'package:flutter/material.dart';

class _FakeStore extends ImportedPluginStore {
  @override
  Future<ImportedPluginResult> install(ImportedNativeModule module) async {
    NativeModuleRegistry.instance.replace(module);
    return ImportedPluginResult(module: module, replaced: false);
  }
}

class _FakeCatalog extends PluginCatalog {
  _FakeCatalog({required this.entries, required this.module})
    : super(indexUri: Uri.parse('http://127.0.0.1:1/index.json'));

  final List<PluginCatalogEntry> entries;
  final ImportedNativeModule module;

  @override
  Future<List<PluginCatalogEntry>> fetch() async => entries;

  @override
  Future<ImportedNativeModule> download(PluginCatalogEntry entry) async =>
      module;
}

PluginManifest _padavanManifest() {
  return PluginManifest.parse(
    (jsonDecode(
      File('examples/native-modules/padavan-wan/plugin.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>).cast<String, Object?>(),
  );
}

const PluginCatalogEntry _entry = PluginCatalogEntry(
  id: 'plugin.padavan-wan',
  name: 'Padavan 路由器',
  version: '1.0.0',
  description: '读取 WAN 状态并控制连接',
  path: 'padavan-wan/plugin.json',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;

  setUp(() async {
    NativeModuleRegistry.instance.resetToDefaults();
    store = _FakeStore();
  });

  tearDown(() async {
    NativeModuleRegistry.instance.resetToDefaults();
  });

  Future<void> pumpSection(WidgetTester tester, _FakeCatalog catalog) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PluginMarketSection(catalog: catalog, store: store),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists catalog plugins and installs after confirmation', (
    WidgetTester tester,
  ) async {
    final ImportedNativeModule module = ImportedNativeModule(
      _padavanManifest(),
    );
    final _FakeCatalog catalog = _FakeCatalog(
      entries: const <PluginCatalogEntry>[_entry],
      module: module,
    );

    await pumpSection(tester, catalog);

    expect(find.text('Padavan 路由器'), findsOneWidget);
    expect(find.text('已安装'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('install-plugin-plugin.padavan-wan')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('install-plugin-plugin.padavan-wan')),
    );
    await tester.pump();
    expect(find.text('安装原生模块？'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-plugin-install')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已安装'), findsOneWidget);
    expect(NativeModuleRegistry.instance.byId('plugin.padavan-wan'), isNotNull);
  });

  testWidgets('marks a plugin that is already installed', (
    WidgetTester tester,
  ) async {
    final ImportedNativeModule module = ImportedNativeModule(
      _padavanManifest(),
    );
    NativeModuleRegistry.instance.replace(module);
    final _FakeCatalog catalog = _FakeCatalog(
      entries: const <PluginCatalogEntry>[_entry],
      module: module,
    );

    await pumpSection(tester, catalog);

    expect(find.text('已安装'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('install-plugin-plugin.padavan-wan')),
      findsNothing,
    );
  });
}
