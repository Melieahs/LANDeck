import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
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
        : repository.devices.where((Device device) {
            final String text =
                '${device.name} ${device.primaryAddress} ${device.deviceType.label}'
                    .toLowerCase();
            return text.contains(query);
          }).toList(growable: false);
    final Set<String> matchingIds =
        services.map((Service service) => service.id).toSet();
    final List<Service> favorites = repository.favorites
        .where((Service service) => query.isEmpty || matchingIds.contains(service.id))
        .toList(growable: false);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            largeTitle: const Text('LANDeck'),
            trailing: CupertinoButton(
              key: const ValueKey<String>('ios-add'),
              padding: EdgeInsets.zero,
              onPressed: _showAddSheet,
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: CupertinoSearchTextField(
                controller: _search,
                placeholder: '搜索服务、设备或 IP',
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Overview(
              serviceCount: repository.services.length,
              deviceCount: repository.devices.length,
              onlineCount: repository.onlineCount,
            ),
          ),
          if (favorites.isNotEmpty || query.isEmpty)
            SliverToBoxAdapter(
              child: _favoritesSection(favorites),
            ),
          if (devices.isNotEmpty || query.isEmpty)
            SliverToBoxAdapter(child: _devicesSection(repository, devices)),
          SliverToBoxAdapter(child: _servicesSection(repository, services)),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _favoritesSection(List<Service> favorites) {
    return CupertinoListSection.insetGrouped(
      header: const Text('收藏'),
      children: favorites.isEmpty
          ? <Widget>[
              const IosEmptyTile(
                title: '还没有收藏的服务',
                subtitle: '在服务详情中点亮收藏后会显示在这里',
              ),
            ]
          : favorites.map((Service service) {
              return CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.heart_fill,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                title: Text(service.name),
                subtitle: Text('${service.categoryLabel} · ${service.address}'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _openService(service),
              );
            }).toList(growable: false),
    );
  }

  Widget _devicesSection(
    LanDeckRepository repository,
    List<Device> devices,
  ) {
    return CupertinoListSection.insetGrouped(
      header: const Text('设备'),
      children: devices.isEmpty
          ? <Widget>[
              IosEmptyTile(
                title: '添加第一台设备',
                subtitle: '设备地址用于自动生成关联服务的访问 URL',
                onTap: _openAddDevice,
              ),
            ]
          : devices.map((Device device) {
              final List<Service> linked = repository.servicesForDevice(device);
              final bool hasOnline = linked.any((Service s) => s.isOnline);
              final bool hasStatus = linked.any((Service s) => s.hasStatus);
              final String status = hasOnline
                  ? '在线'
                  : hasStatus
                  ? '离线'
                  : '未检测';
              return CupertinoListTile(
                leading: Icon(
                  iosDeviceIcon(device.deviceType),
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                title: Text(device.name),
                subtitle: Text(
                  '${device.deviceType.label} · ${device.addressLabel} · $status',
                ),
                additionalInfo: Text('${linked.length} 个服务'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _openDevice(device),
              );
            }).toList(growable: false),
    );
  }

  Widget _servicesSection(
    LanDeckRepository repository,
    List<Service> services,
  ) {
    return CupertinoListSection.insetGrouped(
      header: const Text('全部服务'),
      children: services.isEmpty
          ? <Widget>[
              IosEmptyTile(
                title: _query.isEmpty ? '还没有添加服务' : '没有找到匹配的服务',
                subtitle: _query.isEmpty
                    ? '进入设备详情即可按端口快速添加'
                    : '试试服务名称、设备或 IP 地址',
              ),
            ]
          : services.map((Service service) {
              return CupertinoListTile(
                leading: Icon(
                  iosServiceIcon(service),
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                title: Text(service.name),
                subtitle: Text(
                  '${repository.deviceNameFor(service)} · ${service.address}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IosStatusText(
                      isOnline: service.isOnline,
                      unknown: !service.hasStatus,
                    ),
                    const SizedBox(width: 4),
                    const CupertinoListTileChevron(),
                  ],
                ),
                onTap: () => _openService(service),
              );
            }).toList(growable: false),
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
          actions: repository.devices.map((Device device) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, device),
              child: Text('${device.name} · ${device.addressLabel}'),
            );
          }).toList(growable: false),
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

class _Overview extends StatelessWidget {
  const _Overview({
    required this.serviceCount,
    required this.deviceCount,
    required this.onlineCount,
  });

  final int serviceCount;
  final int deviceCount;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Row(
        children: <Widget>[
          _Metric(value: serviceCount, label: '服务'),
          _Divider(color: secondary),
          _Metric(value: deviceCount, label: '设备'),
          _Divider(color: secondary),
          _Metric(value: onlineCount, label: '在线'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: color.withValues(alpha: 0.25));
  }
}
