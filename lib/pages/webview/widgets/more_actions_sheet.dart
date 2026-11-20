import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/service.dart';
import '../../../widgets/service_icon.dart';
import '../../../widgets/status_dot.dart';

enum MoreAction {
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
  String? currentUrl,
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
        currentUrl: currentUrl,
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
    this.currentUrl,
  });

  final Service service;
  final String deviceName;
  final bool immersive;
  final bool nativeWebView;
  final String? currentUrl;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '更多操作',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${service.name} · ${service.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      _ActionRow(
                        icon: Icons.open_in_new_rounded,
                        title: '在外部浏览器打开',
                        subtitle: nativeWebView
                            ? '使用系统浏览器打开当前页面'
                            : '当前平台请使用外部浏览器',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.openExternal),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.content_copy_rounded,
                        title: '复制地址',
                        subtitle: currentUrl ?? service.url,
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.copyAddress),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.key_rounded,
                        title: '填充登录信息',
                        subtitle: '使用已保存的账号密码填充当前页面',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.fillPassword),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.password_rounded,
                        title: '保存当前登录信息',
                        subtitle: '读取当前网页表单并加密保存在本机',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.savePassword),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.ios_share_rounded,
                        title: '分享地址',
                        subtitle: '分享功能将在后续版本开放',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.shareAddress),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.download_rounded,
                        title: '下载管理',
                        subtitle: '查看进度、打开或分享已下载文件',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.downloads),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.fullscreen_rounded,
                        title: '全屏 / 沉浸模式',
                        subtitle: '隐藏系统栏，专注网页内容',
                        trailing: _StateChip(active: immersive),
                        onTap: () =>
                            Navigator.of(context)
                                .pop(MoreAction.toggleImmersive),
                      ),
                      const _ActionDivider(),
                      _ActionRow(
                        icon: Icons.info_outline_rounded,
                        title: '页面信息',
                        subtitle: '连接、渲染与登录状态',
                        onTap: () =>
                            Navigator.of(context).pop(MoreAction.pageInfo),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nativeWebView
                      ? '页面由系统 WebView 加载；分享功能尚未接入'
                      : '当前平台未启用系统 WebView；分享功能尚未接入',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 57,
      endIndent: 12,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        active ? '已开启' : '已关闭',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
    final MediaQueryData media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    ServiceIconBadge(
                      icon: iconForService(service),
                      size: 38,
                      emphasized: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '页面信息',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      _InfoRow(label: '当前地址', value: currentUrl ?? service.url),
                      const _ActionDivider(),
                      _InfoRow(label: '设备', value: deviceName),
                      const _ActionDivider(),
                      _InfoRow(label: '分类', value: service.categoryLabel),
                      const _ActionDivider(),
                      _InfoRow(
                        label: '状态',
                        value: service.statusLabel,
                        valueColor: service.isOnline
                            ? AppColors.online
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        leadingDot: true,
                      ),
                      const _ActionDivider(),
                      _InfoRow(
                        label: '连接方式',
                        value: nativeWebView ? '局域网直连' : '未加载',
                      ),
                      const _ActionDivider(),
                      _InfoRow(
                        label: '渲染来源',
                        value: nativeWebView ? '系统 WebView' : '未启用',
                      ),
                      const _ActionDivider(),
                      _InfoRow(
                        label: 'Cookie / 登录',
                        value: nativeWebView ? '由系统 WebView 持久化' : '未启用',
                      ),
                      const _ActionDivider(),
                      _InfoRow(
                        label: 'WebView 引擎',
                        value: nativeWebView ? '系统 WebView' : '未接入',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nativeWebView
                      ? '当前页面由系统 WebView 加载，Cookie 与登录状态会随应用数据保留。\n在线状态来自最近一次扫描或页面加载结果，未检测时显示未检测。'
                      : '当前平台没有系统 WebView，未加载任何网页内容。请使用 Android APK 或外部浏览器。\n在线状态来自最近一次扫描或页面加载结果。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.leadingDot = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool leadingDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (leadingDot) ...<Widget>[
                  StatusDot(isOnline: value == '在线', size: 5),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color:
                          valueColor ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
