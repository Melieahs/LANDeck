import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../core/app_scope.dart';
import '../../models/service.dart';
import '../../models/service_mode.dart';
import '../../repositories/service_repository.dart';
import 'widgets/service_switcher_sheet.dart';

/// Desktop (Windows/WebView2) viewer for a service URL.
///
/// `webview_flutter` has no Windows implementation, so desktop uses
/// `webview_windows` (WebView2). It intentionally supports the core browsing
/// flow only: load, back/forward/reload, progress and service switching.
/// Password autofill and download interception remain Android/iOS features.
class WindowsWebViewPage extends StatefulWidget {
  const WindowsWebViewPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<WindowsWebViewPage> createState() => _WindowsWebViewPageState();
}

class _WindowsWebViewPageState extends State<WindowsWebViewPage> {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Service? _service;
  bool _initStarted = false;
  bool _controllerReady = false;
  bool _loading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _error;
  bool _exiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final LanDeckRepository repository = AppScope.of(context);
    final Service? service = repository.serviceById(
      _service?.id ?? widget.serviceId,
    );
    if (!_initStarted) {
      _initStarted = true;
      _service = service;
      if (service != null) {
        unawaited(repository.markServiceOpened(service.id));
        unawaited(_start(service));
      } else {
        setState(() => _loading = false);
      }
      return;
    }
    if (service != null) {
      _service = service;
    }
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _start(Service service) async {
    try {
      await _controller.initialize();
      _subscriptions.add(
        _controller.loadingState.listen((LoadingState state) {
          if (!mounted) {
            return;
          }
          setState(() {
            _loading = state == LoadingState.loading;
            if (!_loading) {
              _error = null;
            }
          });
        }),
      );
      _subscriptions.add(
        _controller.historyChanged.listen((HistoryChanged history) {
          if (!mounted) {
            return;
          }
          setState(() {
            _canGoBack = history.canGoBack;
            _canGoForward = history.canGoForward;
          });
        }),
      );
      _subscriptions.add(
        _controller.onLoadError.listen((WebErrorStatus status) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = '网页加载失败（$status）';
            _loading = false;
          });
        }),
      );
      if (!mounted) {
        return;
      }
      setState(() => _controllerReady = true);
      await _controller.loadUrl(service.url);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '无法启动内嵌浏览器：$error';
        _loading = false;
      });
    }
  }

  void _exit() {
    if (_exiting) {
      return;
    }
    _exiting = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    await _controller.reload();
  }

  Future<void> _openExternally() async {
    final Service? service = _service;
    if (service == null) {
      return;
    }
    final Uri? uri = Uri.tryParse(service.url);
    if (uri == null) {
      return;
    }
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开系统浏览器')));
    }
  }

  Future<void> _openServiceSwitcher() async {
    final LanDeckRepository repository = AppScope.of(context);
    final Service? current = _service;
    if (current == null) {
      return;
    }
    final ServiceSelection? selection = await showServiceSwitcherSheet(
      context,
      services: repository.services,
      current: current,
      currentMode: ServiceMode.web,
      deviceNameFor: repository.deviceNameFor,
      openServiceIds: const <String>{},
    );
    if (selection == null || !mounted) {
      return;
    }
    setState(() {
      _service = selection.service;
      _error = null;
      _loading = true;
      _canGoBack = false;
      _canGoForward = false;
    });
    await _controller.loadUrl(selection.service.url);
  }

  @override
  Widget build(BuildContext context) {
    final Service? service = _service;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey<String>('windows-webview-exit'),
          tooltip: '退出',
          onPressed: _exit,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: service == null
            ? const Text('服务')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    Uri.tryParse(service.url)?.host ?? service.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('windows-webview-back'),
            tooltip: '后退',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _canGoBack ? _controller.goBack : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-forward'),
            tooltip: '前进',
            icon: const Icon(Icons.redo_rounded),
            onPressed: _canGoForward ? _controller.goForward : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-reload'),
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controllerReady ? _reload : null,
          ),
          IconButton(
            key: const ValueKey<String>('windows-webview-service-switch'),
            tooltip: '切换服务',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: service == null ? null : _openServiceSwitcher,
          ),
        ],
      ),
      body: _buildBody(service),
    );
  }

  Widget _buildBody(Service? service) {
    if (service == null) {
      return const Center(child: Text('服务不存在或已被删除'));
    }
    if (_error != null) {
      return _WindowsWebError(
        message: _error!,
        onRetry: _reload,
        onOpenExternal: _openExternally,
      );
    }
    if (!_controllerReady) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(height: 14),
            Text('正在启动内嵌浏览器…'),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: Webview(_controller)),
      ],
    );
  }
}

class _WindowsWebError extends StatelessWidget {
  const _WindowsWebError({
    required this.message,
    required this.onRetry,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.public_off_rounded,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: onOpenExternal,
                    child: const Text('用系统浏览器打开'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
