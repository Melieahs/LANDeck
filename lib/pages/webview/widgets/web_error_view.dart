import 'package:material_ui/material_ui.dart';

import '../../../models/service.dart';
import '../../../widgets/service_icon.dart';

/// Lightweight connection error shown inside the WebView surface.
class WebErrorView extends StatelessWidget {
  const WebErrorView({
    super.key,
    required this.service,
    required this.onRetry,
    required this.onSwitchService,
    this.detail,
    this.nativeWebView = false,
  });

  final Service service;
  final VoidCallback onRetry;
  final VoidCallback onSwitchService;

  /// Optional platform error text. Kept short so it never pushes the actions
  /// below the fold on small phones.
  final String? detail;

  /// Whether this surface is backed by a real platform WebView.
  final bool nativeWebView;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: <Widget>[
                ServiceIconBadge(
                  icon: iconForService(service),
                  size: 36,
                  emphasized: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        service.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '连接失败',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Card.outlined(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              size: 26,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '无法访问此服务',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${service.name} · ${service.address}',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '设备可能已离线，或服务没有在局域网中运行。\n请确认设备电源与网络连接后重试。',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              height: 1.6,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (detail != null &&
                              detail!.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: onRetry,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('重试'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onSwitchService,
                                  child: const Text('切换服务'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                nativeWebView
                                    ? Icons.lock_outline_rounded
                                    : Icons.phone_android_rounded,
                                size: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  nativeWebView
                                      ? '系统 WebView · 已尝试局域网连接'
                                      : '当前平台未启用系统 WebView',
                                  textAlign: TextAlign.center,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
