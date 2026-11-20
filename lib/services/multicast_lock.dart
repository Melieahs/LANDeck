import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android filters inbound multicast packets unless the app holds a
/// WifiManager.MulticastLock. The tiny native bridge lives in MainActivity.
class MulticastLock {
  static const MethodChannel _channel = MethodChannel(
    'com.example.landeck/network',
  );

  bool _held = false;

  Future<void> acquire() async {
    if (kIsWeb || _held) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
      _held = true;
    } on Object {
      // mDNS may still work on some devices; SSDP/TCP scans are unaffected.
    }
  }

  Future<void> release() async {
    if (kIsWeb || !_held) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } on Object {
      // Best effort.
    }
    _held = false;
  }
}
