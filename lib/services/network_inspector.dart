import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../core/utils/network_utils.dart';
import '../models/scan_candidate.dart';

class NetworkInspectionException implements Exception {
  const NetworkInspectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the active Wi-Fi IPv4 address and subnet mask.
///
/// A scan only runs when a real address and mask are available. Nothing is
/// guessed: without a mask the user gets an actionable error instead.
class NetworkInspector {
  const NetworkInspector();

  Future<LanNetworkInfo> inspect() async {
    if (kIsWeb) {
      throw const NetworkInspectionException('网页版无法扫描局域网，请使用 Android APK');
    }

    final NetworkInfo info = NetworkInfo();
    String? wifiIp;
    String? mask;
    String? gateway;
    try {
      wifiIp = await info.getWifiIP();
      mask = await info.getWifiSubmask();
      gateway = await info.getWifiGatewayIP();
    } on Object {
      // Fall through to the interface probe below.
    }

    if (wifiIp == null || wifiIp == '0.0.0.0') {
      wifiIp = await detectLocalIPv4();
    }
    if (wifiIp == null || wifiIp == '0.0.0.0') {
      throw const NetworkInspectionException(
        '没有检测到局域网地址，请先连接 Wi-Fi 或网线后重试',
      );
    }

    final int? prefix = prefixFromSubnetMask(mask);
    if (prefix == null) {
      throw const NetworkInspectionException(
        '无法获取当前 Wi-Fi 的子网掩码，暂时不能安全地计算扫描范围',
      );
    }
    if (prefix > 30) {
      throw const NetworkInspectionException('当前网段没有可扫描的其他主机');
    }
    if (prefix < 23) {
      throw NetworkInspectionException(
        '当前网段过大（/$prefix），为避免影响局域网，仅支持 /23 或更小的网段',
      );
    }

    return LanNetworkInfo(
      interfaceName: 'Wi-Fi',
      ipAddress: wifiIp,
      prefixLength: prefix,
      subnetMask: mask ?? subnetMaskFromPrefix(prefix)!,
      gateway: gateway,
    );
  }
}
