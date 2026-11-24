import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_cef/webview_cef.dart';

import '../../core/app_scope.dart';
import '../../core/utils/feedback.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../repositories/service_repository.dart';
import 'widgets/more_actions_sheet.dart';
import 'widgets/service_switcher_sheet.dart';
import 'widgets/web_error_view.dart';
import 'widgets/webview_bar_action.dart';

/// Web viewer for macOS backed by CEF (Chromium Embedded Framework).
///
/// The pinned CEF release is old enough to run on macOS 10.15 while still
/// providing a modern Chromium engine, which the system WKWebView does not.
/// Frames are presented through a Flutter texture, so this page does not rely
/// on the macOS platform-view compositor at all.
class CefWebViewPage extends StatefulWidget {
  const CefWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<CefWebViewPage> createState() => _CefWebViewPageState();
}

class _CefWebViewPageState extends State<CefWebViewPage> {
  final WebviewManager _manager = WebviewManager();
  WebViewController? _controller;
  Service? _service;

  bool _opening = true;
  bool _pageLoading = false;
  bool _hasError = false;
  String? _error;
  String? _currentUrl;
  String? _title;
  final bool _canGoBack = false;
  final bool _canGoForward = false;
  bool _cefReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    final Service? current = repository.serviceById(widget.serviceId);
    if (current != null && _service == null) {
      _service = current;
      unawaited(_open(current));
    }
  }

  Future<void> _open(Service service) async {
    setState(() {
      _opening = true;
      _hasError = false;
      _error = null;
    });
    try {
      if (!_cefReady) {
        await _manager.initialize();
        _cefReady = true;
      }
      final WebViewController controller =
          _manager.createWebView(loading: const SizedBox.shrink());
      controller.setWebviewListener(
        WebviewEventsListener(
          onTitleChanged: (String title) {
            if (!mounted) {
              return;
            }
            setState(() {
              _title = title;
            });
          },
          onUrlChanged: (String url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentUrl = url;
            });
          },
          onLoadStart: (WebViewController c, String url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pageLoading = true;
              _currentUrl = url;
            });
          },
          onLoadEnd: (WebViewController c, String url) {
            if (!mounted) {
              return;
            }
            setState(() {
              _pageLoading = false;
              _currentUrl = url;
            });
          },
        ),
      );
      await controller.initialize(service.url);
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = controller;
        _opening = false;
        _currentUrl = service.url;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _opening = false;
        _hasError = true;
        _error = error.toString();
      });
    }
  }

  String _statusLabel(Service service) {
    if (_hasError) {
      return '加载失败：${_error ?? '未知错误'}';
    }
    if (_opening) {
      return '正在启动浏览器内核';
    }
    if (_pageLoading) {
      return '加载中 · ${_currentUrl ?? service.url}';
    }
    final String? title = _title;
    if (title != null && title.trim().isNotEmpty && title != service.name) {
      return '$title · ${_currentUrl ?? service.url}';
    }
    return '已加载 · ${_currentUrl ?? service.url}';
  }

  Future<void> _exit() async {
    final WebViewController? controller = _controller;
    setState(() {
      _controller = null;
    });
    await controller?.dispose();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _back() async {
    try {
      await _controller?.goBack();
    } on Object {
      // CEF reports navigation failures asynchronously; nothing to surface.
    }
  }

  Future<void> _forward() async {
    try {
      await _controller?.goForward();
    } on Object {
      // Ignore: the page may not have forward history.
    }
  }

  Future<void> _reload() async {
    try {
      await _controller?.reload();
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, '刷新失败：$error');
      }
    }
  }

  Future<void> _copyAddress() async {
    final String? url = _currentUrl ?? _service?.url;
    if (url == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      showAppSnackBar(context, '已复制地址');
    }
  }

  Future<void> _openExternal() async {
    final String? url = _currentUrl ?? _service?.url;
    if (url == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (mounted) {
        showAppSnackBar(context, '无法打开系统浏览器');
      }
    }
  }

  Future<void> _openServiceSwitcher(Service service) async {
    final LanDeckRepository repository = AppScope.of(context);
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: service,
      currentMode: ServiceMode.web,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: const <String>{},
    );
    if (!mounted || selection == null || selection.service.id == service.id) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CefWebViewPage(serviceId: selection.service.id),
      ),
    );
  }

  Future<void> _showMore(Service service) async {
    final LanDeckRepository repository = AppScope.of(context);
    final String deviceName = repository.deviceNameFor(service);
    final MoreAction? action = await showMoreActionsSheet(
      context,
      service: service,
      deviceName: deviceName,
      immersive: false,
      nativeWebView: false,
      canGoForward: _canGoForward,
      currentUrl: _currentUrl,
      includeImmersive: false,
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MoreAction.refresh:
        await _reload();
      case MoreAction.goForward:
        await _forward();
      case MoreAction.openExternal:
        await _openExternal();
      case MoreAction.copyAddress:
        await _copyAddress();
      case MoreAction.fillPassword:
      case MoreAction.savePassword:
      case MoreAction.shareAddress:
        showAppSnackBar(context, '该操作暂未在 macOS 版开放');
      case MoreAction.downloads:
        showAppSnackBar(context, '下载保存由浏览器内核处理');
      case MoreAction.toggleImmersive:
        break;
      case MoreAction.pageInfo:
        await showPageInfoSheet(
          context,
          service: service,
          deviceName: deviceName,
          currentUrl: _currentUrl,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Service? service = _service;

    if (service == null) {
      return Scaffold(
        appBar: webViewerAppBar(
          surface: scheme.surfaceContainer,
          leading: WebViewBarAction(
            icon: Icons.close_rounded,
            tooltip: '退出',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text('服务'),
          actions: const <Widget>[],
        ),
        body: const Center(child: Text('服务不存在或已被删除')),
      );
    }

    return Scaffold(
      appBar: webViewerAppBar(
        surface: scheme.surfaceContainer,
        leading: WebViewBarAction(
          icon: Icons.close_rounded,
          tooltip: '退出',
          onPressed: _exit,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              service.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15.5,
              ),
            ),
            Text(
              _statusLabel(service),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          WebViewBarAction(
            icon: Icons.undo_rounded,
            tooltip: '后退',
            onPressed: _canGoBack ? _back : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.redo_rounded,
            tooltip: '前进',
            onPressed: _canGoForward ? _forward : null,
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.more_horiz_rounded,
            tooltip: '更多',
            onPressed: () => _showMore(service),
          ),
          const SizedBox(width: 4),
          WebViewBarAction(
            icon: Icons.swap_horiz_rounded,
            tooltip: '切换服务',
            onPressed: () => _openServiceSwitcher(service),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _hasError
          ? WebErrorView(
              service: service,
              onRetry: () => _open(service),
              onSwitchService: () => _openServiceSwitcher(service),
              detail: _error,
            )
          : _opening || _controller == null
              ? const Center(child: CircularProgressIndicator())
              : _controller!.webviewWidget,
    );
  }
}
