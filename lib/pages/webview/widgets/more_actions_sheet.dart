import 'package:material_ui/material_ui.dart';

import '../../../models/service.dart';
import '../../../widgets/service_icon.dart';

enum MoreAction {
  refresh,
  goForward,
  openExternal,
  copyAddress,
  fillPassword,
  savePassword,
  shareAddress,
  downloads,
  toggleImmersive,
  pageInfo,
}

/// Returns the action chosen from the "more" sheet.
Future<MoreAction?> showMoreActionsSheet(
  BuildContext context, {
  required Service service,
  required String deviceName,
  required bool immersive,
  required bool nativeWebView,
  required bool canGoForward,
  String? currentUrl,
  bool includeImmersive = true,
}) {
  return showModalBottomSheet<MoreAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (BuildContext context) {
      return _MoreActionsSheet(
        service: service,
        deviceName: deviceName,
        immersive: immersive,
        nativeWebView: nativeWebView,
        canGoForward: canGoForward,
        currentUrl: currentUrl,
        includeImmersive: includeImmersive,
      );
    },
  );
}

class _MoreActionsSheet extends StatelessWidget {
  const _MoreActionsSheet({
    required this.service,
    required this.deviceName,
    required this.immersive,
    required this.nativeWebView,
    required this.canGoForward,
    this.currentUrl,
    this.includeImmersive = true,
  });

  final Service service;
  final String deviceName;
  final bool immersive;
  final bool nativeWebView;
  final bool canGoForward;
  final String? currentUrl;
  final bool includeImmersive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: _DragHandle(color: scheme.onSurfaceVariant)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 0, 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '更多操作',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${service.name} · ${service.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '关闭',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _ActionRow(
                  icon: Icons.refresh_rounded,
                  title: '刷新',
                  subtitle: '重新加载当前页面',
                  onTap: () => Navigator.of(context).pop(MoreAction.refresh),
                ),
                _ActionRow(
                  icon: Icons.arrow_forward_rounded,
                  title: '前进',
                  subtitle: canGoForward ? '前往下一页' : '当前没有可前进的页面',
                  onTap: canGoForward
                      ? () => Navigator.of(context).pop(MoreAction.goForward)
                      : null,
                ),
                _ActionRow(
                  icon: Icons.open_in_new_rounded,
                  title: '在外部浏览器打开',
                  subtitle: nativeWebView ? '使用系统浏览器打开当前页面' : '当前平台请使用外部浏览器',
                  onTap: () =>
                      Navigator.of(context).pop(MoreAction.openExternal),
                ),
                _ActionRow(
                  icon: Icons.content_copy_rounded,
                  title: '复制地址',
                  subtitle: currentUrl ?? service.url,
                  onTap: () =>
                      Navigator.of(context).pop(MoreAction.copyAddress),
                ),
                _ActionRow(
                  icon: Icons.key_rounded,
                  title: '填充登录信息',
                  subtitle: '使用已保存的账号密码填充当前页面',
                  onTap: () =>
                      Navigator.of(context).pop(MoreAction.fillPassword),
                ),
                _ActionRow(
                  icon: Icons.password_rounded,
                  title: '保存当前登录信息',
                  subtitle: '读取当前网页表单并加密保存在本机',
                  onTap: () =>
                      Navigator.of(context).pop(MoreAction.savePassword),
                ),
                _ActionRow(
                  icon: Icons.ios_share_rounded,
                  title: '分享地址',
                  subtitle: '分享功能将在后续版本开放',
                  onTap: () =>
                      Navigator.of(context).pop(MoreAction.shareAddress),
                ),
                _ActionRow(
                  icon: Icons.download_rounded,
                  title: '下载管理',
                  subtitle: '查看进度、打开或分享已下载文件',
                  onTap: () => Navigator.of(context).pop(MoreAction.downloads),
                ),
                if (includeImmersive)
                  _ActionRow(
                    icon: Icons.fullscreen_rounded,
                    title: '全屏 / 沉浸模式',
                    subtitle: '隐藏系统栏，专注网页内容',
                    trailing: _StateChip(active: immersive),
                    onTap: () =>
                        Navigator.of(context).pop(MoreAction.toggleImmersive),
                  ),
                _ActionRow(
                  icon: Icons.info_outline_rounded,
                  title: '页面信息',
                  subtitle: '连接、渲染与登录状态',
                  onTap: () => Navigator.of(context).pop(MoreAction.pageInfo),
                ),
                const SizedBox(height: 6),
                Text(
                  nativeWebView
                      ? '页面由系统 WebView 加载；分享功能尚未接入'
                      : '当前平台未启用系统 WebView；分享功能尚未接入',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        active ? '已开启' : '已关闭',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Small read-only sheet describing the real service page.
Future<void> showPageInfoSheet(
  BuildContext context, {
  required Service service,
  required String deviceName,
  String? currentUrl,
  bool nativeWebView = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (BuildContext context) => _PageInfoSheet(
      service: service,
      deviceName: deviceName,
      currentUrl: currentUrl,
      nativeWebView: nativeWebView,
    ),
  );
}

class _PageInfoSheet extends StatelessWidget {
  const _PageInfoSheet({
    required this.service,
    required this.deviceName,
    this.currentUrl,
    this.nativeWebView = false,
  });

  final Service service;
  final String deviceName;
  final String? currentUrl;
  final bool nativeWebView;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaQueryData media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DragHandle(color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    ServiceIconBadge(
                      icon: iconForService(service),
                      size: 40,
                      emphasized: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '页面信息',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      _InfoRow(label: '当前地址', value: currentUrl ?? service.url),
                      _InfoRow(label: '设备', value: deviceName),
                      _InfoRow(label: '分类', value: service.categoryLabel),
                      _InfoRow(
                        label: '连接方式',
                        value: nativeWebView ? '局域网直连' : '未加载',
                      ),
                      _InfoRow(
                        label: '渲染来源',
                        value: nativeWebView ? '系统 WebView' : '未启用',
                      ),
                      _InfoRow(
                        label: 'Cookie / 登录',
                        value: nativeWebView ? '由系统 WebView 持久化' : '未启用',
                      ),
                      _InfoRow(
                        label: 'WebView 引擎',
                        value: nativeWebView ? '系统 WebView' : '未接入',
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  nativeWebView
                      ? '当前页面由系统 WebView 加载，Cookie 与登录状态会随应用数据保留。'
                      : '当前平台没有系统 WebView，未加载任何网页内容。请使用 Android APK 或外部浏览器。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
