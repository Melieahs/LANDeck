import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../glass/ios_glass_header.dart';
import '../ios_widgets.dart';
import 'ios_device_detail_page.dart';
import 'ios_device_editor_page.dart';
import 'ios_quick_add_service_page.dart';

class IosHomePage extends StatefulWidget {
  const IosHomePage({super.key});

  @override
  State<IosHomePage> createState() => _IosHomePageState();
}

class _IosHomePageState extends State<IosHomePage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final String query = _query.trim().toLowerCase();
    final List<Service> services = query.isEmpty
        ? repository.services
        : repository.searchServices(query);
    final List<Device> devices = query.isEmpty
        ? repository.devices
        : repository.devices
              .where((Device device) {
                final String text =
                    '${device.name} ${device.primaryAddress} ${device.deviceType.label}'
                        .toLowerCase();
                return text.contains(query);
              })
              .toList(growable: false);
    final Set<String> matchingIds = services
        .map((Service service) => service.id)
        .toSet();
    final List<Service> favorites = repository.favorites
        .where(
          (Service service) =>
              query.isEmpty || matchingIds.contains(service.id),
        )
        .toList(growable: false);
    final double topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, topInset + 78, 20, 132),
                sliver: SliverList.list(
                  children: <Widget>[
                    CupertinoSearchTextField(
                      controller: _search,
                      placeholder: '搜索服务、设备或 IP',
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      onChanged: (String value) =>
                          setState(() => _query = value),
                    ),
                    const SizedBox(height: 14),
                    _OverviewLine(
                      serviceCount: repository.services.length,
                      deviceCount: repository.devices.length,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: '收藏'),
                    const SizedBox(height: 10),
                    _favorites(favorites),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      title: '设备',
                      trailing: devices.isEmpty
                          ? null
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: _openAddDevice,
                              child: const Text(
                                '添加',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    _devices(repository, devices),
                    const SizedBox(height: 26),
                    _SectionHeader(title: '全部服务'),
                    const SizedBox(height: 4),
                    _services(repository, services),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: topInset + 8,
          left: 16,
          right: 16,
          child: SizedBox(
            height: 54,
            child: IosGlassHeader(title: 'LANDeck', onAdd: _showAddSheet),
          ),
        ),
      ],
    );
  }

  Widget _favorites(List<Service> favorites) {
    if (favorites.isEmpty) {
      return Text(
        _query.isEmpty ? '收藏常用服务后会显示在这里。' : '没有匹配的收藏。',
        style: TextStyle(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      );
    }
    return Wrap(
      spacing: 22,
      runSpacing: 14,
      children: favorites
          .map((Service service) {
            return _FavoriteItem(
              service: service,
              onTap: () => _openService(service),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _devices(LanDeckRepository repository, List<Device> devices) {
    if (devices.isEmpty) {
      return _EmptyAction(
        title: _query.isEmpty ? '添加第一台设备' : '没有匹配的设备',
        subtitle: _query.isEmpty ? '设备地址用于自动生成关联服务的访问 URL' : '试试设备名称或 IP 地址',
        action: _query.isEmpty ? _openAddDevice : null,
        actionText: '添加设备',
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < devices.length; i++) ...<Widget>[
          _DeviceRow(
            device: devices[i],
            serviceCount: repository.servicesForDevice(devices[i]).length,
            repository: repository,
            onTap: () => _openDevice(devices[i]),
          ),
          if (i != devices.length - 1) const _Hairline(),
        ],
      ],
    );
  }

  Widget _services(LanDeckRepository repository, List<Service> services) {
    if (services.isEmpty) {
      return _EmptyAction(
        title: _query.isEmpty ? '还没有添加服务' : '没有找到匹配的服务',
        subtitle: _query.isEmpty ? '进入设备详情，输入端口即可创建服务' : '试试服务名称、设备或 IP 地址',
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < services.length; i++) ...<Widget>[
          _ServiceRow(
            service: services[i],
            deviceName: repository.deviceNameFor(services[i]),
            onTap: () => _openService(services[i]),
          ),
          if (i != services.length - 1) const _Hairline(),
        ],
      ],
    );
  }

  Future<void> _showAddSheet() async {
    final _AddAction? action = await showCupertinoModalPopup<_AddAction>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('添加'),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _AddAction.device),
              child: const Text('添加设备'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, _AddAction.service),
              child: const Text('添加服务'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _AddAction.device) {
      _openAddDevice();
    } else {
      _chooseDeviceForService();
    }
  }

  void _openAddDevice() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) => const IosDeviceEditorPage(),
      ),
    );
  }

  Future<void> _chooseDeviceForService() async {
    final LanDeckRepository repository = AppScope.of(context);
    if (repository.devices.isEmpty) {
      await _message('请先添加设备', '服务需要关联一台设备，也可以稍后使用完整 URL 添加。');
      return;
    }
    final Device? device = await showCupertinoModalPopup<Device>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('选择设备'),
          actions: repository.devices
              .map((Device device) {
                return CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, device),
                  child: Text('${device.name} · ${device.addressLabel}'),
                );
              })
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (!mounted || device == null) {
      return;
    }
    await _openQuickAdd(device);
  }

  Future<void> _openQuickAdd(Device device) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) => IosQuickAddServicePage(
          deviceId: device.id,
          deviceName: device.name,
          deviceAddress: device.addressLabel,
        ),
      ),
    );
  }

  void _openDevice(Device device) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (BuildContext context) =>
            IosDeviceDetailPage(deviceId: device.id),
      ),
    );
  }

  Future<void> _openService(Service service) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(service.name),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              service.url.isEmpty
                  ? '该服务还没有可用地址。'
                  : '${service.url}\n\niOS WebView 将在后续阶段接入。',
            ),
          ),
          actions: <Widget>[
            if (service.url.isNotEmpty)
              CupertinoDialogAction(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: service.url));
                  Navigator.pop(context);
                },
                child: const Text('复制地址'),
              ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _message(String title, String body) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}

enum _AddAction { device, service }

class _OverviewLine extends StatelessWidget {
  const _OverviewLine({required this.serviceCount, required this.deviceCount});

  final int serviceCount;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final TextStyle number = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: CupertinoColors.label.resolveFrom(context),
    );
    final TextStyle label = TextStyle(fontSize: 13, color: secondary);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$serviceCount', style: number),
          TextSpan(text: ' 个服务   ', style: label),
          TextSpan(text: '$deviceCount', style: number),
          TextSpan(text: ' 台设备', style: label),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _FavoriteItem extends StatelessWidget {
  const _FavoriteItem({required this.service, required this.onTap});

  final Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            iosServiceIcon(service),
            size: 20,
            color: CupertinoColors.systemBlue.resolveFrom(context),
          ),
          const SizedBox(width: 7),
          Text(
            service.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.serviceCount,
    required this.repository,
    required this.onTap,
  });

  final Device device;
  final int serviceCount;
  final LanDeckRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapRow(
      onTap: onTap,
      leading: Icon(
        iosDeviceIcon(device.deviceType),
        size: 25,
        color: CupertinoColors.systemBlue.resolveFrom(context),
      ),
      title: device.name,
      subtitle: '${device.deviceType.label} · ${device.addressLabel}',
      trailing: Text(
        '$serviceCount 个服务',
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.deviceName,
    required this.onTap,
  });

  final Service service;
  final String deviceName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return _TapRow(
      onTap: onTap,
      leading: Icon(
        iosServiceIcon(service),
        size: 23,
        color: CupertinoColors.systemBlue.resolveFrom(context),
      ),
      title: service.name,
      subtitle: '$deviceName · ${service.address}',
      trailing: Icon(
        CupertinoIcons.chevron_forward,
        size: 13,
        color: secondary,
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.45,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            SizedBox(width: 30, child: leading),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Container(
        height: 0.5,
        color: CupertinoColors.separator
            .resolveFrom(context)
            .withValues(alpha: 0.55),
      ),
    );
  }
}

class _EmptyAction extends StatelessWidget {
  const _EmptyAction({
    required this.title,
    required this.subtitle,
    this.action,
    this.actionText,
  });

  final String title;
  final String subtitle;
  final VoidCallback? action;
  final String? actionText;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          if (action != null && actionText != null) ...<Widget>[
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: action,
              child: Text(actionText!, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
    if (action == null) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: action,
      child: content,
    );
  }
}
