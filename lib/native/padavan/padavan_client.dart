import 'dart:convert';

import 'package:http/http.dart' as http;

/// A real Padavan web UI client for the three WAN/WISP actions exposed on
/// `/device-map/internet.asp`.
///
/// The router authenticates with HTTP Basic. No cookie, CSRF token or Referer
/// is required by the firmware, but the browser-style Referer is included so
/// the request looks like the original form submission.
class PadavanClient {
  PadavanClient({
    required this.baseUri,
    required this.username,
    required this.password,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final String username;
  final String password;
  final Duration timeout;
  final http.Client _client;

  static const String wanReconnect = 'Connect';
  static const String wanDisconnect = 'Disconnect';
  static const String wispReassoc = 'WispReassoc';

  Uri get _statusUri => baseUri.resolve('/device-map/internet.asp');
  Uri get _actionUri => baseUri.resolve('/device-map/wan_action.asp');

  Map<String, String> get _headers => <String, String>{
    'Authorization':
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    'Referer': _statusUri.toString(),
    'Accept': 'text/html,application/xhtml+xml',
  };

  /// Reads the same status functions that the router's own status page uses.
  Future<PadavanStatus> fetchStatus() async {
    final http.Response response = await _client
        .get(_statusUri, headers: _headers)
        .timeout(timeout);
    if (response.statusCode == 401) {
      throw PadavanAuthException(
        '路由器要求登录',
        realm: _realm(response),
      );
    }
    if (response.statusCode != 200) {
      throw PadavanException('路由器返回 HTTP ${response.statusCode}');
    }
    final String html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_looksLikeLoginConflict(html)) {
      throw PadavanAuthException('路由器已有其它管理会话，请先注销该会话');
    }
    final PadavanStatus? status = PadavanStatus.tryParse(html);
    if (status == null) {
      throw PadavanException('页面不是预期的 Padavan 状态页，未找到 wanlink_status()');
    }
    return status;
  }

  /// Executes one of [wanReconnect], [wanDisconnect] or [wispReassoc].
  ///
  /// The router accepts the request with HTTP 200 and returns a reload delay;
  /// it does not return a success flag. Call [fetchStatus] afterwards to
  /// determine the actual result.
  Future<PadavanActionResult> perform(String action) async {
    if (action != wanReconnect &&
        action != wanDisconnect &&
        action != wispReassoc) {
      throw ArgumentError.value(action, 'action', 'Unsupported Padavan action');
    }
    final http.Response response = await _client
        .post(
          _actionUri,
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: <String, String>{
            'wan_action': action,
            // The firmware ignores this for the three actions, but the browser
            // form always submits the current modem priority.
            'modem_prio': '0',
          },
        )
        .timeout(timeout);
    if (response.statusCode == 401) {
      throw PadavanAuthException(
        '路由器要求登录',
        realm: _realm(response),
      );
    }
    if (response.statusCode != 200) {
      throw PadavanException('路由器返回 HTTP ${response.statusCode}');
    }
    final String html = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (_looksLikeLoginConflict(html)) {
      throw PadavanAuthException('路由器已有其它管理会话，请先注销该会话');
    }
    final RegExpMatch? match = RegExp(
      r'restart_needed_time\((\d+)\)',
    ).firstMatch(html);
    if (match == null) {
      throw PadavanException('未收到 Padavan 操作确认，可能未登录或页面不兼容');
    }
    return PadavanActionResult(
      action: action,
      reloadSeconds: int.parse(match.group(1)!),
    );
  }

  void close() => _client.close();

  String? _realm(http.Response response) {
    final String? challenge = response.headers['www-authenticate'];
    if (challenge == null) {
      return null;
    }
    final RegExpMatch? match = RegExp(
      r'realm="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(challenge);
    return match?.group(1);
  }

  bool _looksLikeLoginConflict(String html) =>
      html.contains('已登录用户 IP') || html.contains('请先注销另一用户');
}

class PadavanStatus {
  const PadavanStatus({
    required this.statusCode,
    required this.type,
    required this.wanIp,
    required this.gateway,
    required this.dns,
    required this.uptimeSeconds,
    required this.etherLink,
    required this.apCliLink,
  });

  final int statusCode;
  final String type;
  final String wanIp;
  final String gateway;
  final String dns;
  final int uptimeSeconds;
  final String etherLink;
  final String apCliLink;

  bool get connected => statusCode == 0;

  String get stateLabel {
    switch (statusCode) {
      case 0:
        return '已连接';
      case 1:
        return '未插入网线';
      case 2:
        return '未连接到上级 WISP AP';
      case 3:
        return '未连接到上级蜂窝基站';
      case 4:
        return '网络接口未就绪';
      case 5:
        return '正在获取 IP 地址';
      case 6:
        return '等待 PPP 客户端连接';
      case 7:
        return 'PPP 连接未激活';
      case 8:
        return '未设置默认网关';
      case 9:
        return 'WAN 与 LAN 子网冲突';
      default:
        return '未知状态 ($statusCode)';
    }
  }

  String get uptimeLabel {
    if (uptimeSeconds <= 0) {
      return '—';
    }
    final int days = uptimeSeconds ~/ 86400;
    final int hours = (uptimeSeconds % 86400) ~/ 3600;
    final int minutes = (uptimeSeconds % 3600) ~/ 60;
    if (days > 0) {
      return '$days 天 $hours 小时';
    }
    if (hours > 0) {
      return '$hours 小时 $minutes 分';
    }
    return '$minutes 分';
  }

  static PadavanStatus? tryParse(String html) {
    final Map<String, String> strings = <String, String>{};
    final Map<String, int> numbers = <String, int>{};

    final RegExp stringFunction = RegExp(
      r"function\s+wanlink_(\w+)\s*\(\s*\)\s*\{\s*return\s+'((?:\\.|[^'])*)'\s*;\s*\}",
    );
    for (final RegExpMatch match in stringFunction.allMatches(html)) {
      strings[match.group(1)!] = match
          .group(2)!
          .replaceAll(r"\'", "'");
    }

    final RegExp numberFunction = RegExp(
      r'function\s+wanlink_(\w+)\s*\(\s*\)\s*\{\s*return\s+(\d+)\s*;\s*\}',
    );
    for (final RegExpMatch match in numberFunction.allMatches(html)) {
      numbers[match.group(1)!] = int.parse(match.group(2)!);
    }

    final int? status = numbers['status'];
    if (status == null) {
      return null;
    }
    return PadavanStatus(
      statusCode: status,
      type: strings['type'] ?? '—',
      wanIp: _emptyAsDash(strings['ip4_wan']),
      gateway: _emptyAsDash(strings['gw4_wan']),
      dns: _emptyAsDash(strings['dns']),
      uptimeSeconds: numbers['uptime'] ?? 0,
      etherLink: _emptyAsDash(strings['etherlink']),
      apCliLink: _emptyAsDash(strings['apclilink']),
    );
  }

  static String _emptyAsDash(String? value) {
    if (value == null || value.trim().isEmpty || value == '---') {
      return '—';
    }
    return value;
  }
}

class PadavanActionResult {
  const PadavanActionResult({
    required this.action,
    required this.reloadSeconds,
  });

  final String action;
  final int reloadSeconds;
}

class PadavanException implements Exception {
  const PadavanException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PadavanAuthException extends PadavanException {
  const PadavanAuthException(super.message, {this.realm});

  final String? realm;
}
