import 'dart:convert';

import 'package:flutter/services.dart';

/// Thin typed wrapper around the Android foreground download service.
class NativeDownloadBridge {
  const NativeDownloadBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.example.landeck/downloads',
  );

  Future<bool> start({
    required String taskId,
    required String url,
    required String fileName,
    required String? mimeType,
    required String destinationUri,
    required Map<String, String> headers,
  }) async {
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        'start',
        <String, Object?>{
          'taskId': taskId,
          'url': url,
          'fileName': fileName,
          'mimeType': mimeType,
          'destinationUri': destinationUri,
          'headers': jsonEncode(headers),
        },
      );
      return started ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, Object?>?> query(String taskId) async {
    try {
      return await _channel.invokeMapMethod<String, Object?>('query', taskId);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> cancel(String taskId) async {
    try {
      await _channel.invokeMethod<void>('cancel', taskId);
    } on PlatformException {
      // The task may have finished between the tap and the call.
    } on MissingPluginException {
      // Unsupported platform; the UI remains usable.
    }
  }

  Future<bool> openFile({
    required String uri,
    required String? mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('open', <String, Object?>{
            'uri': uri,
            'mimeType': mimeType,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> shareFile({
    required String uri,
    required String? mimeType,
    required String fileName,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('share', <String, Object?>{
            'uri': uri,
            'mimeType': mimeType,
            'fileName': fileName,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class InternalFile {
  const InternalFile({
    required this.name,
    required this.path,
    required this.uri,
    required this.size,
    required this.modified,
    required this.isDirectory,
  });

  final String name;
  final String path;
  final String uri;
  final int size;
  final DateTime modified;
  final bool isDirectory;
}

class NativeFileBridge {
  const NativeFileBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.example.landeck/files',
  );

  Future<List<String>> pickFiles({
    required List<String> acceptTypes,
    required bool multiple,
    bool capture = false,
  }) async {
    try {
      final List<Object?>? result = await _channel.invokeListMethod<Object?>(
        'pickFiles',
        <String, Object?>{
          'acceptTypes': acceptTypes,
          'multiple': multiple,
          'capture': capture,
        },
      );
      return result
              ?.whereType<String>()
              .where((String value) => value.isNotEmpty)
              .toList() ??
          <String>[];
    } on PlatformException {
      return <String>[];
    } on MissingPluginException {
      return <String>[];
    }
  }

  Future<List<String>> pickFolderFiles() async {
    try {
      final List<Object?>? result = await _channel.invokeListMethod<Object?>(
        'pickFolderFiles',
      );
      return result
              ?.whereType<String>()
              .where((String value) => value.isNotEmpty)
              .toList() ??
          <String>[];
    } on PlatformException {
      return <String>[];
    } on MissingPluginException {
      return <String>[];
    }
  }

  Future<List<InternalFile>> listInternalFiles({String path = ''}) async {
    return _listInternal('listInternalFiles', path);
  }

  Future<List<InternalFile>> listInternalFilesRecursive({
    String path = '',
  }) async {
    return _listInternal('listInternalFilesRecursive', path);
  }

  Future<List<InternalFile>> _listInternal(String method, String path) async {
    try {
      final List<Object?>? result = await _channel.invokeListMethod<Object?>(
        method,
        <String, Object?>{'path': path},
      );
      return result
              ?.whereType<Map<Object?, Object?>>()
              .map(_entryFromMap)
              .where((InternalFile file) => file.name.isNotEmpty)
              .toList() ??
          <InternalFile>[];
    } on PlatformException {
      return <InternalFile>[];
    } on MissingPluginException {
      return <InternalFile>[];
    }
  }

  static InternalFile _entryFromMap(Map<Object?, Object?> raw) {
    return InternalFile(
      name: raw['name'] as String? ?? '',
      path: raw['path'] as String? ?? '',
      uri: raw['uri'] as String? ?? '',
      size: (raw['size'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (raw['modified'] as num?)?.toInt() ?? 0,
      ),
      isDirectory: raw['isDirectory'] as bool? ?? false,
    );
  }

  Future<String?> createInternalFile({
    required String path,
    required String name,
  }) async {
    try {
      return await _channel.invokeMethod<String>('createInternalFile', <String, Object?>{
        'path': path,
        'name': name,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String?> createInternalFolder({
    required String path,
    required String name,
  }) async {
    try {
      return await _channel.invokeMethod<String>(
        'createInternalFolder',
        <String, Object?>{'path': path, 'name': name},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<String?> renameInternalEntry({
    required String path,
    required String newName,
  }) async {
    try {
      return await _channel.invokeMethod<String>(
        'renameInternalEntry',
        <String, Object?>{'path': path, 'newName': newName},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> deleteInternalEntry({required String path}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'deleteInternalEntry',
            <String, Object?>{'path': path},
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String?> pickSaveFile({
    required String fileName,
    required String? mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<String>(
        'pickSaveFile',
        <String, Object?>{'fileName': fileName, 'mimeType': mimeType},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
