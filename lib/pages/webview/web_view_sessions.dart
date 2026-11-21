import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

/// One live WebView kept alive in the background.
///
/// Switching services only changes which session is visible; the controller
/// and its page state stay alive so coming back does not reload the site.
class WebViewSession {
  WebViewSession({required this.serviceId, required this.controller});

  final String serviceId;
  final WebViewController controller;

  bool canGoBack = false;
  bool canGoForward = false;
  bool hasError = false;
  String? error;
  double progress = 1;
  DateTime lastUsedAt = DateTime.now();
}

/// Keeps a small LRU set of live [WebViewSession]s for the viewer.
class WebViewSessionRegistry {
  WebViewSessionRegistry._();

  static final WebViewSessionRegistry instance = WebViewSessionRegistry._();

  /// Beyond a handful of tabs the memory cost outweighs the benefit.
  static const int maxSessions = 4;

  final Map<String, WebViewSession> _sessions = <String, WebViewSession>{};

  int get count => _sessions.length;

  Set<String> get serviceIds => _sessions.keys.toSet();

  List<WebViewSession> get sessions =>
      List<WebViewSession>.unmodifiable(_sessions.values);

  WebViewSession? byService(String serviceId) => _sessions[serviceId];

  /// Stores [session] and returns it, evicting the least recently used tab
  /// when the registry is full.
  WebViewSession register(WebViewSession session) {
    final WebViewSession? existing = _sessions[session.serviceId];
    if (existing != null && !identical(existing, session)) {
      _discard(existing);
    }
    session.lastUsedAt = DateTime.now();
    _sessions[session.serviceId] = session;
    _trim();
    return session;
  }

  void touch(WebViewSession session) {
    session.lastUsedAt = DateTime.now();
  }

  void close(String serviceId) {
    final WebViewSession? session = _sessions.remove(serviceId);
    if (session != null) {
      _discard(session);
    }
  }

  void closeAll() {
    for (final WebViewSession session in _sessions.values) {
      _discard(session);
    }
    _sessions.clear();
  }

  /// webview_flutter does not expose a controller dispose; blank the page so a
  /// dropped session stops holding onto its document while it is collected.
  void _discard(WebViewSession session) {
    unawaited(
      session.controller.loadRequest(Uri.parse('about:blank')).catchError((
        Object _,
      ) {
        return null;
      }),
    );
  }

  void _trim() {
    while (_sessions.length > maxSessions) {
      String? oldestId;
      DateTime? oldest;
      for (final MapEntry<String, WebViewSession> entry in _sessions.entries) {
        if (oldest == null || entry.value.lastUsedAt.isBefore(oldest)) {
          oldest = entry.value.lastUsedAt;
          oldestId = entry.key;
        }
      }
      if (oldestId == null) {
        return;
      }
      close(oldestId);
    }
  }
}
