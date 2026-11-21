import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'imported_module_store.dart';
import 'plugin_manifest.dart';

/// Thrown when the remote plugin catalog cannot be read.
class PluginCatalogException implements Exception {
  const PluginCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A declArative plugin advertised by the remote catalog.
class PluginCatalogEntry {
  const PluginCatalogEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.path,
    this.author,
    this.baseUri,
  });

  final String id;
  final String name;
  final String version;
  final String description;

  /// Relative path of the manifest below the catalog URL.
  final String path;
  final String? author;

  /// Index address this entry was loaded from; falls back to the catalog's
  /// primary index when the entry was built by hand.
  final Uri? baseUri;
}

/// Reads the declarative plugin index from the LANDeck GitHub repository and
/// downloads individual manifests. Plugins stay declarative: nothing is
/// executed and every manifest is validated by [ImportedPluginStore].
class PluginCatalog {
  PluginCatalog({
    Uri? indexUri,
    Uri? fallbackIndexUri,
    this.timeout = const Duration(seconds: 12),
  }) : indexUri = indexUri ?? defaultIndexUri,
       fallbackIndexUri = indexUri == null
           ? (fallbackIndexUri ?? defaultFallbackIndexUri)
           : fallbackIndexUri;

  /// Plugin index shipped in the repository.
  static final Uri defaultIndexUri = Uri.parse(
    'https://raw.githubusercontent.com/Melieahs/LANDeck/main/examples/native-modules/index.json',
  );

  /// Temporary mirror for the native-modules branch before it is merged into
  /// `main`. Remove this once the plugin index is on the default branch.
  static final Uri defaultFallbackIndexUri = Uri.parse(
    'https://raw.githubusercontent.com/Melieahs/LANDeck/feature/native-modules/examples/native-modules/index.json',
  );

  static final PluginCatalog instance = PluginCatalog();

  static const int maxIndexBytes = 128 * 1024;

  final Uri indexUri;
  final Uri? fallbackIndexUri;
  final Duration timeout;

  /// Loads and validates the plugin index. Falls back to the development
  /// branch mirror while the default branch has no index yet.
  Future<List<PluginCatalogEntry>> fetch() async {
    try {
      return await _fetchIndex(indexUri);
    } on PluginCatalogException catch (primaryError) {
      final Uri? fallback = fallbackIndexUri;
      if (fallback == null || fallback == indexUri) {
        rethrow;
      }
      try {
        return await _fetchIndex(fallback);
      } on PluginCatalogException {
        throw primaryError;
      }
    }
  }

  Future<List<PluginCatalogEntry>> _fetchIndex(Uri source) async {
    final Uint8List bytes = await _get(source, maxIndexBytes);
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const PluginCatalogException('插件索引不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw const PluginCatalogException('插件索引必须是 JSON 对象');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const PluginCatalogException('不支持的插件索引版本');
    }
    final Object? rawPlugins = decoded['plugins'];
    if (rawPlugins is! List) {
      throw const PluginCatalogException('插件索引缺少 plugins 列表');
    }
    final List<PluginCatalogEntry> entries = <PluginCatalogEntry>[];
    final Set<String> ids = <String>{};
    for (final Object? item in rawPlugins) {
      if (item is! Map) {
        throw const PluginCatalogException('插件索引条目格式错误');
      }
      final PluginCatalogEntry entry = _parseEntry(item, source);
      if (!ids.add(entry.id)) {
        throw PluginCatalogException('插件索引包含重复的 id：${entry.id}');
      }
      entries.add(entry);
    }
    return List<PluginCatalogEntry>.unmodifiable(entries);
  }

  /// Downloads [entry] and returns the validated declarative module.
  Future<ImportedNativeModule> download(PluginCatalogEntry entry) async {
    final Uri uri = (entry.baseUri ?? indexUri).resolve(entry.path);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw PluginCatalogException('插件地址不合法：${entry.path}');
    }
    final Uint8List bytes = await _get(
      uri,
      ImportedPluginStore.maxManifestBytes,
    );
    return ImportedPluginStore.instance.previewBytes(
      bytes,
      fileName: entry.path.split('/').last,
    );
  }

  PluginCatalogEntry _parseEntry(Map<Object?, Object?> json, Uri source) {
    String requireText(String key) {
      final Object? value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw PluginCatalogException('插件索引条目缺少 $key');
      }
      return value.trim();
    }

    final String id = requireText('id');
    if (!id.startsWith('plugin.')) {
      throw PluginCatalogException('插件 id 必须以 plugin. 开头：$id');
    }
    final String path = requireText('path');
    if (!_isSafeRelativePath(path)) {
      throw PluginCatalogException('插件路径不合法：$path');
    }
    final Object? author = json['author'];
    return PluginCatalogEntry(
      id: id,
      name: requireText('name'),
      version: requireText('version'),
      description: requireText('description'),
      path: path,
      author: author is String && author.trim().isNotEmpty
          ? author.trim()
          : null,
      baseUri: source,
    );
  }

  static bool _isSafeRelativePath(String path) {
    final Uri? uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.path.startsWith('/') ||
        path.contains('\\') ||
        !uri.path.endsWith('.json')) {
      return false;
    }
    for (final String segment in uri.pathSegments) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return false;
      }
    }
    return uri.pathSegments.isNotEmpty;
  }

  Future<Uint8List> _get(Uri uri, int maxBytes) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw PluginCatalogException('不支持的地址：$uri');
    }
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client
          .getUrl(uri)
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'LANDeck-PluginCatalog/1.0',
      );
      final HttpClientResponse response = await request.close().timeout(
        timeout,
      );
      if (response.statusCode != HttpStatus.ok) {
        throw PluginCatalogException('下载插件失败（HTTP ${response.statusCode}）');
      }
      final int length = response.contentLength;
      if (length > maxBytes) {
        throw const PluginCatalogException('插件响应过大');
      }
      final BytesBuilder builder = BytesBuilder(copy: false);
      await for (final List<int> chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw const PluginCatalogException('插件响应过大');
        }
      }
      return builder.takeBytes();
    } on SocketException catch (error) {
      throw PluginCatalogException('无法连接插件源：$error');
    } on HandshakeException catch (error) {
      throw PluginCatalogException('插件源证书校验失败：$error');
    } on TimeoutException {
      throw const PluginCatalogException('连接插件源超时');
    } finally {
      client.close(force: true);
    }
  }
}
