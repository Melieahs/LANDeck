import 'dart:io';

import 'package:flutter/foundation.dart';

/// IPv4 subnet helpers used before a real LAN scan.
///
/// The helpers are pure so the scan range can be unit tested without touching
/// the network.
int? prefixFromSubnetMask(String? mask) {
  if (mask == null) {
    return null;
  }
  final List<int>? parts = _parseIPv4(mask);
  if (parts == null) {
    return null;
  }
  int prefix = 0;
  bool seenZero = false;
  for (final int part in parts) {
    for (int bit = 7; bit >= 0; bit--) {
      final bool set = (part & (1 << bit)) != 0;
      if (set) {
        if (seenZero) {
          return null;
        }
        prefix++;
      } else {
        seenZero = true;
      }
    }
  }
  return prefix;
}

String? subnetMaskFromPrefix(int prefix) {
  if (prefix < 0 || prefix > 32) {
    return null;
  }
  final int mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  return '${(mask >> 24) & 255}.${(mask >> 16) & 255}.${(mask >> 8) & 255}.${mask & 255}';
}

int hostCountForPrefix(int prefix) {
  if (prefix < 0 || prefix > 32) {
    return 0;
  }
  if (prefix >= 31) {
    return prefix == 32 ? 1 : 2;
  }
  return (1 << (32 - prefix)) - 2;
}

/// Returns usable host addresses (network and broadcast excluded).
List<String> hostsForCidr(String ip, int prefix) {
  final List<int>? address = _parseIPv4(ip);
  if (address == null || prefix < 0 || prefix > 32) {
    return const <String>[];
  }
  final int ipInt =
      (address[0] << 24) | (address[1] << 16) | (address[2] << 8) | address[3];
  final int mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final int network = ipInt & mask;
  final int broadcast = network | (~mask & 0xFFFFFFFF);

  int start = network + 1;
  int end = broadcast - 1;
  if (prefix >= 31) {
    start = network;
    end = broadcast;
  }
  final List<String> hosts = <String>[];
  for (int value = start; value <= end && value >= start; value++) {
    hosts.add(_formatIPv4(value));
  }
  if (hosts.isEmpty && prefix <= 31) {
    hosts.add(_formatIPv4(ipInt));
  }
  // Keep the phone itself as a legitimate host; callers may skip it.
  return hosts.where((String host) => host != '0.0.0.0').toList();
}

String cidrLabel(String ip, int prefix) => '$ip/$prefix';

String _formatIPv4(int value) {
  return '${(value >> 24) & 255}.${(value >> 16) & 255}.${(value >> 8) & 255}.${value & 255}';
}

List<int>? _parseIPv4(String value) {
  final List<String> parts = value.trim().split('.');
  if (parts.length != 4) {
    return null;
  }
  final List<int> result = <int>[];
  for (final String part in parts) {
    final int? number = int.tryParse(part);
    if (number == null || number < 0 || number > 255) {
      return null;
    }
    result.add(number);
  }
  return result;
}

/// Detects the IPv4 address of the active interface (Wi-Fi or Ethernet).
///
/// This is only a fallback for [network_info_plus]; it cannot provide a subnet
/// mask, so callers must not invent one silently.
Future<String?> detectLocalIPv4() async {
  if (kIsWeb) {
    return null;
  }
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final NetworkInterface interface in interfaces) {
      final String name = interface.name.toLowerCase();
      final bool looksPhysical =
          name.startsWith('wlan') ||
          name.startsWith('wifi') ||
          name.startsWith('en') ||
          name.startsWith('eth') ||
          name.startsWith('ap');
      if (!looksPhysical) {
        continue;
      }
      for (final InternetAddress address in interface.addresses) {
        if (!address.isLoopback && !address.address.startsWith('169.254.')) {
          return address.address;
        }
      }
    }
  } on Object {
    return null;
  }
  return null;
}
