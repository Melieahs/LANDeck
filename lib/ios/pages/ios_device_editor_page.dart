import 'package:cupertino_ui/cupertino_ui.dart';

import '../../core/app_scope.dart';
import '../../models/device.dart';
import '../../repositories/service_repository.dart';

class IosDeviceEditorPage extends StatefulWidget {
  const IosDeviceEditorPage({super.key, this.device});

  final Device? device;

  @override
  State<IosDeviceEditorPage> createState() => _IosDeviceEditorPageState();
}

class _IosDeviceEditorPageState extends State<IosDeviceEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late DeviceType _type;
  bool _saving = false;

  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    final Device? device = widget.device;
    _name = TextEditingController(text: device?.name ?? '');
    _address = TextEditingController(text: device?.primaryAddress ?? '');
    _notes = TextEditingController(text: device?.notes ?? '');
    _type = device?.deviceType ?? DeviceType.nas;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? '编辑设备' : '添加设备'),
        trailing: CupertinoButton(
          key: const ValueKey<String>('ios-device-save'),
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator(radius: 9)
              : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            children: <Widget>[
              CupertinoFormSection.insetGrouped(
                header: const Text('设备信息'),
                children: <Widget>[
                  CupertinoTextFormFieldRow(
                    key: const ValueKey<String>('ios-device-name'),
                    controller: _name,
                    prefix: const Text('名称'),
                    placeholder: '例如：客厅 NAS',
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入设备名称';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    key: const ValueKey<String>('ios-device-address'),
                    controller: _address,
                    prefix: const Text('地址'),
                    placeholder: '192.168.1.10 或 nas.local',
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入设备地址';
                      }
                      return null;
                    },
                  ),
                  CupertinoFormRow(
                    prefix: const Text('类型'),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _pickType,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(_type.label),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 15,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('备注'),
                children: <Widget>[
                  CupertinoTextFormFieldRow(
                    controller: _notes,
                    placeholder: '可选，例如机房位置、用途',
                    maxLines: 3,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 4, 32, 0),
                child: Text(
                  '设备地址只填写 IP 或主机名，不要包含 http://、端口或路径。修改地址后，关联服务的 URL 会自动更新。',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickType() async {
    final DeviceType? selected = await showCupertinoModalPopup<DeviceType>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text('设备类型'),
          actions: DeviceType.values.map((DeviceType type) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type.label),
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
    if (selected != null && mounted) {
      setState(() => _type = selected);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final LanDeckRepository repository = AppScope.of(context);
    try {
      final Device saved;
      if (_isEditing) {
        saved = await repository.updateDevice(
          widget.device!.copyWith(
            name: _name.text.trim(),
            primaryAddress: _address.text.trim(),
            deviceType: _type,
            notes: () => _notes.text.trim(),
          ),
        );
      } else {
        saved = await repository.addDevice(
          name: _name.text.trim(),
          deviceType: _type,
          primaryAddress: _address.text.trim(),
          notes: _notes.text.trim(),
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } on DeviceConflictException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        await _message('无法保存', error.message);
      }
    }
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
