import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../models/service.dart';
import '../native_module.dart';
import 'imported_native_page.dart';

/// Thrown when a plugin package or manifest is invalid.
class PluginManifestException implements Exception {
  const PluginManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Restricts where a plugin may be offered. Both lists are optional.
class PluginMatch {
  PluginMatch({List<String> hostPatterns = const <String>[], List<int> ports = const <int>[]})
      : hostPatterns = List<String>.unmodifiable(hostPatterns),
        ports = List<int>.unmodifiable(ports);

  final List<String> hostPatterns;
  final List<int> ports;

  bool matches(Service service) {
    final Uri? uri = service.uri;
    final String host = uri?.host ?? '';
    final int? port = uri == null
        ? null
        : uri.hasPort
            ? uri.port
            : uri.scheme == 'https'
                ? 443
                : 80;
    if (hostPatterns.isNotEmpty &&
        !hostPatterns.any((String pattern) => _glob(pattern, host))) {
      return false;
    }
    if (ports.isNotEmpty && (port == null || !ports.contains(port))) {
      return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        if (hostPatterns.isNotEmpty) 'hostPatterns': hostPatterns,
        if (ports.isNotEmpty) 'ports': ports,
      };

  static bool _glob(String pattern, String value) {
    final String p = pattern.toLowerCase();
    final String v = value.toLowerCase();
    final StringBuffer regex = StringBuffer('^');
    for (final int rune in p.runes) {
      if (rune == 42) {
        regex.write('.*');
      } else if (rune == 63) {
        regex.write('.');
      } else {
        regex.write(RegExp.escape(String.fromCharCode(rune)));
      }
    }
    regex.write(r'$');
    return RegExp(regex.toString()).hasMatch(v);
  }
}

class PluginField {
  const PluginField({
    required this.label,
    this.path,
    this.pattern,
    this.group = 1,
    this.map = const <String, String>{},
  });

  final String label;
  final String? path;
  final String? pattern;
  final int group;
  final Map<String, String> map;

  String? resolve(Object? json, String text) {
    String? raw;
    if (path != null && path!.isNotEmpty) {
      Object? value = json;
      for (final String part in path!.split('.')) {
        if (value is Map && value.containsKey(part)) {
          value = value[part];
        } else {
          value = null;
          break;
        }
      }
      raw = value?.toString();
    } else if (pattern != null && pattern!.isNotEmpty) {
      final RegExpMatch? match = RegExp(pattern!, dotAll: true).firstMatch(text);
      raw = match?.group(group);
    }
    if (raw == null) {
      return null;
    }
    return map[raw] ?? raw;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'label': label,
        if (path != null) 'path': path,
        if (pattern != null) 'pattern': pattern,
        if (group != 1) 'group': group,
        if (map.isNotEmpty) 'map': map,
      };
}

class PluginRequest {
  const PluginRequest({
    this.method = 'GET',
    required this.path,
    this.query = const <String, String>{},
    this.form = const <String, String>{},
    this.json,
    this.headers = const <String, String>{},
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> form;
  final Object? json;
  final Map<String, String> headers;

  Uri resolve(Uri base) {
    if (path.contains('://')) {
      throw const PluginManifestException('请求路径不能是完整 URL');
    }
    final Uri root = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);
    final Uri target = root.resolve(path.startsWith('/') ? path : '/$path');
    if (target.host != base.host || target.scheme != base.scheme) {
      throw const PluginManifestException('请求路径必须位于当前服务主机');
    }
    return target.replace(queryParameters: <String, String>{...target.queryParameters, ...query});
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'method': method,
        'path': path,
        if (query.isNotEmpty) 'query': query,
        if (form.isNotEmpty) 'form': form,
        if (json != null) 'json': json,
        if (headers.isNotEmpty) 'headers': headers,
      };
}

class PluginAction {
  const PluginAction({
    required this.id,
    required this.label,
    required this.request,
    this.icon = 'play',
    this.description,
    this.confirmText,
    this.refreshDelaySeconds = 1,
  });

  final String id;
  final String label;
  final String icon;
  final String? description;
  final String? confirmText;
  final PluginRequest request;
  final int refreshDelaySeconds;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'icon': icon,
        if (description != null) 'description': description,
        if (confirmText != null) 'confirmText': confirmText,
        'refreshDelaySeconds': refreshDelaySeconds,
        'request': request.toJson(),
      };
}

class PluginManifest {
  static const int supportedSchemaVersion = 1;
  static const int maxActions = 8;
  static const int maxFields = 16;

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String description;
  final String? author;
  final String? homepage;
  final List<String> permissions;
  final PluginMatch? match;
  final bool basicAuth;
  final PluginRequest? status;
  final List<PluginField> fields;
  final List<PluginAction> actions;

  static PluginManifest parse(Map<String, Object?> json) {
    final int schema = _int(json['schemaVersion'], 1);
    if (schema != supportedSchemaVersion) {
      throw PluginManifestException('不支持的插件格式版本：$schema');
    }
    final String id = _string(json['id']);
    if (!RegExp(r'^plugin\.[a-z0-9][a-z0-9._-]*$').hasMatch(id)) {
      throw const PluginManifestException('插件 id 必须以 plugin. 开头，仅使用小写字母、数字、点、下划线和连字符');
    }
    final String name = _string(json['name']);
    final String version = _string(json['version']);
    final String description = _string(json['description']);
    final List<String> permissions = _stringList(json['permissions'] ?? <String>['http']);
    if (permissions.any((String item) => item != 'http')) {
      throw const PluginManifestException('当前版本仅支持 http 权限');
    }
    final Map<String, Object?>? matchJson = _mapOrNull(json['match']);
    final PluginMatch? match = matchJson == null
        ? null
        : PluginMatch(
            hostPatterns: _stringList(matchJson['hostPatterns'] ?? const <String>[]),
            ports: _intList(matchJson['ports'] ?? const <int>[]),
          );
    final Map<String, Object?>? statusJson = _mapOrNull(json['status']);
    final PluginRequest? status = statusJson == null
        ? null
        : _request(statusJson, allowMethod: true);
    final List<PluginField> fields = <PluginField>[];
    if (statusJson != null) {
      final Object? fieldsJson = statusJson['fields'];
      if (fieldsJson != null) {
        if (fieldsJson is! List) {
          throw const PluginManifestException('status.fields 必须是数组');
        }
        for (final Object? item in fieldsJson) {
          final Map<String, Object?> field = _map(item, 'status.fields');
          fields.add(PluginField(
            label: _string(field['label']),
            path: _stringOrNull(field['path']),
            pattern: _stringOrNull(field['pattern']),
            group: _int(field['group'], 1),
            map: _stringMap(field['map']),
          ));
        }
      }
    }
    if (fields.length > maxFields) {
      throw const PluginManifestException('状态字段过多（最多 $maxFields 个）');
    }
    final List<PluginAction> actions = <PluginAction>[];
    final Object? actionsJson = json['actions'];
    if (actionsJson != null) {
      if (actionsJson is! List) {
        throw const PluginManifestException('actions 必须是数组');
      }
      if (actionsJson.length > maxActions) {
        throw const PluginManifestException('操作过多（最多 $maxActions 个）');
      }
      for (final Object? item in actionsJson) {
        final Map<String, Object?> action = _map(item, 'actions');
        actions.add(PluginAction(
          id: _string(action['id']),
          label: _string(action['label']),
          icon: _stringOrNull(action['icon']) ?? 'play',
          description: _stringOrNull(action['description']),
          confirmText: _stringOrNull(action['confirmText']),
          refreshDelaySeconds: _int(action['refreshDelaySeconds'], 1).clamp(0, 120),
          request: _request(_map(action['request'], 'actions.request')),
        ));
      }
    }
    return PluginManifest._(
      schemaVersion: schema,
      id: id,
      name: name,
      version: version,
      description: description,
      author: _stringOrNull(json['author']),
      homepage: _stringOrNull(json['homepage']),
      permissions: permissions,
      match: match,
      basicAuth: json['basicAuth'] == true,
      status: status,
      fields: fields,
      actions: actions,
    );
  }

  PluginManifest._({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.homepage,
    required this.permissions,
    required this.match,
    required this.basicAuth,
    required this.status,
    required this.fields,
    required this.actions,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        if (author != null) 'author': author,
        if (homepage != null) 'homepage': homepage,
        'permissions': permissions,
        if (match != null) 'match': match!.toJson(),
        'basicAuth': basicAuth,
        if (status != null)
          'status': <String, Object?>{
            ...status!.toJson(),
            'fields': fields.map((PluginField item) => item.toJson()).toList(growable: false),
          },
        'actions': actions.map((PluginAction item) => item.toJson()).toList(growable: false),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static PluginRequest _request(Map<String, Object?> json, {bool allowMethod = true}) {
    final String path = _string(json['path']);
    if (!path.startsWith('/')) {
      throw const PluginManifestException('请求路径必须以 / 开头');
    }
    final String method = (_stringOrNull(json['method']) ?? 'GET').toUpperCase();
    if (!allowMethod && method != 'GET') {
      throw const PluginManifestException('状态请求只支持 GET');
    }
    if (!const <String>['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(method)) {
      throw PluginManifestException('不支持的请求方法：$method');
    }
    return PluginRequest(
      method: method,
      path: path,
      query: _stringMap(json['query']),
      form: _stringMap(json['form']),
      json: json['json'],
      headers: _stringMap(json['headers']),
    );
  }

  static Map<String, Object?> _map(Object? value, String label) {
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry(key.toString(), item));
    }
    throw PluginManifestException('$label 必须是对象');
  }

  static Map<String, Object?>? _mapOrNull(Object? value) => value == null ? null : _map(value, '字段');

  static String _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw const PluginManifestException('缺少必填文本字段');
  }

  static String? _stringOrNull(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int _int(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.map((Object? item) => item.toString()).toList(growable: false);
    }
    throw const PluginManifestException('应为字符串数组');
  }

  static List<int> _intList(Object? value) {
    if (value is List) {
      return value.map((Object? item) => _int(item, -1)).where((int item) => item > 0).toList(growable: false);
    }
    throw const PluginManifestException('应为数字数组');
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value == null) {
      return const <String, String>{};
    }
    if (value is Map) {
      return value.map((Object? key, Object? item) => MapEntry(key.toString(), item.toString()));
    }
    throw const PluginManifestException('应为键值对象');
  }
}

class ImportedNativeModule extends NativeModule {
  ImportedNativeModule(this.manifest);

  final PluginManifest manifest;

  @override
  String get id => manifest.id;

  @override
  String get name => manifest.name;

  @override
  String get version => manifest.version;

  @override
  String get description => manifest.description;

  @override
  bool get isBuiltin => false;

  @override
  bool supports(Service service) => service.hasUrl && (manifest.match?.matches(service) ?? true);

  @override
  Widget buildPage(BuildContext context, Service service) {
    // ImportedNativePage is in a separate file to keep this model UI-light.
    return ImportedNativePage(module: this, service: service);
  }
}

IconData pluginActionIcon(String name) {
  return switch (name) {
    'refresh' => Icons.refresh_rounded,
    'power' => Icons.power_settings_new_rounded,
    'wifi' => Icons.wifi_rounded,
    'settings' => Icons.settings_rounded,
    'restart' => Icons.restart_alt_rounded,
    'download' => Icons.download_rounded,
    'upload' => Icons.upload_rounded,
    'play' => Icons.play_arrow_rounded,
    'stop' => Icons.stop_rounded,
    _ => Icons.bolt_rounded,
  };
}
