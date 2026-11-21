import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../ios_widgets.dart';
import 'ios_device_editor_page.dart';
import 'ios_quick_add_service_page.dart';

class IosDeviceDetailPage extends StatelessWidget {
  const IosDeviceDetailPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(deviceId);
    if (device == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('设备')),
        child: const Center(child: Text('设备不存在或已被删除')),
      );
    }
    final List<Service> services = repository.servicesForDevice(device);

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            largeTitle: Text(device.name),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showActions(context, repository, device),
              child: const Icon(CupertinoIcons.ellipsis_circle),
            ),
          ),
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: const Text('设备信息'),
              children: <Widget>[
                CupertinoListTile(
                  leading: Icon(
                    iosDeviceIcon(device.deviceType),
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  title: const Text('地址'),
                  additionalInfo: Text(device.addressLabel),
                ),
                CupertinoListTile(
                  title: const Text('类型'),
                  additionalInfo: Text(device.deviceType.label),
                ),
                if (device.notes != null && device.notes!.trim().isNotEmpty)
                  CupertinoListTile(
                    title: const Text('备注'),
                    subtitle: Text(device.notes!),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: CupertinoListSection.insetGrouped(
              header: Text('服务 · ${services.length}'),
              // ignore: sort_child_properties_last
              children: <Widget>[
                ...services.map((Service service) {
                  return CupertinoListTile(
                    leading: Icon(
                      iosServiceIcon(service),
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                    title: Text(service.name),
                    subtitle: Text(
                      '${service.address}${service.pathLabel.isEmpty ? '' : ' · ${service.pathLabel}'}',
                    ),
                    onTap: () => _openService(context, service),
                  );
                }),
                if (services.isEmpty)
                  const IosEmptyTile(
                    title: '还没有服务',
                    subtitle: '使用下方“添加服务”，只需填写端口即可',
                  ),
                CupertinoListTile(
                  leading: Icon(
                    CupertinoIcons.plus_circle,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  title: const Text('添加服务'),
                  subtitle: const Text('使用设备地址自动生成访问 URL'),
                  onTap: () => _openQuickAdd(context, device),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.wifi),
                  title: const Text('扫描该设备的服务端口'),
                  subtitle: const Text('仅扫描这台设备，不扫描整个局域网'),
                  onTap: () => _showPhase(context),
                ),
              ],
              footer: const Text('修改设备地址后，所有关联服务的 URL 会自动更新。'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    LanDeckRepository repository,
    Device device,
  ) async {
    final _DeviceAction? action = await showCupertinoModalPopup<_DeviceAction>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(device.name),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DeviceAction.edit),
            child: const Text('编辑设备'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, _DeviceAction.delete),
            isDestructiveAction: true,
            child: const Text('删除设备'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action == _DeviceAction.edit) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (BuildContext context) =>
              IosDeviceEditorPage(device: device),
        ),
      );
      return;
    }
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('删除设备？'),
        content: const Text('关联服务不会被删除，现有 URL 会保留并移动到「未分配设备」。'),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await repository.deleteDevice(device.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openQuickAdd(BuildContext context, Device device) {
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

  Future<void> _openService(BuildContext context, Service service) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
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
      ),
    );
  }

  Future<void> _showPhase(BuildContext context) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('端口扫描'),
        content: const Text('iOS 单设备端口扫描将在 Phase E 接入，当前不会伪造扫描结果。'),
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

enum _DeviceAction { edit, delete }
