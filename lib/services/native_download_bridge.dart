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
      final bool? started = await _channel.invokeMethod<bool>('start', <String, Object?>{
        'taskId': taskId,
        'url': url,
        'fileName': fileName,
        'mimeType': mimeType,
        'destinationUri': destinationUri,
        'headers': jsonEncode(headers),
      });
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
      final List<Object?>? result = await _channel
          .invokeListMethod<Object?>('pickFiles', <String, Object?>{
            'acceptTypes': acceptTypes,
            'multiple': multiple,
            'capture': capture,
          });
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

  Future<String?> pickSaveFile({
    required String fileName,
    required String? mimeType,
  }) async {
    try {
      return await _channel.invokeMethod<String>('pickSaveFile', <String, Object?>{
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
