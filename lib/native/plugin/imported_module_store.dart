import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'plugin_manifest.dart';
import '../native_module_registry.dart';

class ImportedPluginResult {
  const ImportedPluginResult({required this.module, required this.replaced});

  final ImportedNativeModule module;
  final bool replaced;
}

/// Stores imported plugin manifests as JSON files in the app support directory.
///
/// Plugins are declarative only. Nothing is executed at import time; the
/// manifest is validated and rendered by [ImportedNativePage].
class ImportedPluginStore {
  // ignore: prefer_initializing_formals
  ImportedPluginStore({Directory? directory}) : _directory = directory;

  static final ImportedPluginStore instance = ImportedPluginStore();

  static const int maxPackageBytes = 512 * 1024;
  static const int maxManifestBytes = 128 * 1024;

  Directory? _directory;

  Future<Directory> _dir() async {
    final Directory? existing = _directory;
    if (existing != null) {
      await existing.create(recursive: true);
      return existing;
    }
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/native_modules');
    await dir.create(recursive: true);
    _directory = dir;
    return dir;
  }

  @visibleForTesting
  Future<void> resetDirectory() async {
    final Directory dir = await _dir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }

  Future<List<ImportedNativeModule>> loadAll() async {
    final Directory dir = await _dir();
    final List<ImportedNativeModule> modules = <ImportedNativeModule>[];
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      try {
        final String text = await entity.readAsString();
        final Object? decoded = jsonDecode(text);
        if (decoded is! Map) {
          continue;
        }
        final PluginManifest manifest = PluginManifest.parse(
          decoded.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
        );
        modules.add(ImportedNativeModule(manifest));
      } on Object catch (error) {
        debugPrint('Ignoring invalid native module ${entity.path}: $error');
      }
    }
    modules.sort((ImportedNativeModule a, ImportedNativeModule b) => a.name.compareTo(b.name));
    return modules;
  }

  Future<void> registerInstalled() async {
    final List<ImportedNativeModule> modules = await loadAll();
    for (final ImportedNativeModule module in modules) {
      NativeModuleRegistry.instance.replace(module);
    }
  }

  Future<ImportedNativeModule> previewBytes(Uint8List bytes, {String? fileName}) async {
    if (bytes.length > maxPackageBytes) {
      throw const PluginManifestException('插件包过大（最大 512 KB）');
    }
    final Uint8List manifestBytes = _extractManifest(bytes, fileName);
    if (manifestBytes.length > maxManifestBytes) {
      throw const PluginManifestException('插件清单过大（最大 128 KB）');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(manifestBytes));
    } on FormatException {
      throw const PluginManifestException('插件清单不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw const PluginManifestException('插件清单必须是 JSON 对象');
    }
    final PluginManifest manifest = PluginManifest.parse(
      decoded.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
    return ImportedNativeModule(manifest);
  }

  Future<ImportedPluginResult> install(ImportedNativeModule module) async {
    final Directory dir = await _dir();
    final File target = File('${dir.path}/${module.id}.json');
    final bool replaced = await target.exists();
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(module.manifest.encode(), flush: true);
    await temp.rename(target.path);
    NativeModuleRegistry.instance.replace(module);
    return ImportedPluginResult(module: module, replaced: replaced);
  }

  Future<ImportedPluginResult> importBytes(Uint8List bytes, {String? fileName}) async {
    final ImportedNativeModule module = await previewBytes(bytes, fileName: fileName);
    return install(module);
  }

  Uint8List _extractManifest(Uint8List bytes, String? fileName) {
    final bool zip = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b;
    if (!zip) {
      return bytes;
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } on Object {
      throw const PluginManifestException('无法解压插件包');
    }
    ArchiveFile? manifest;
    for (final ArchiveFile file in archive) {
      final String name = file.name.replaceAll('\\', '/');
      if (!file.isFile) {
        continue;
      }
      if (name == 'plugin.json' || name.endsWith('/plugin.json')) {
        manifest = file;
        break;
      }
    }
    if (manifest == null) {
      throw const PluginManifestException('插件包缺少 plugin.json');
    }
    final List<int>? raw = manifest.content;
    final Uint8List? content = raw == null ? null : Uint8List.fromList(raw);
    if (content == null) {
      throw const PluginManifestException('无法读取插件清单');
    }
    return content;
  }

  Future<void> delete(String id) async {
    final Directory dir = await _dir();
    final File file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
    NativeModuleRegistry.instance.unregister(id);
  }
}
