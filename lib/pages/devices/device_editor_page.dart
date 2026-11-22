import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/url_utils.dart';
import '../../models/device.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/service_icon.dart';

class DeviceEditorPage extends StatefulWidget {
  const DeviceEditorPage({
    super.key,
    this.device,
    this.initialName,
    this.initialAddress,
    this.initialType,
  });

  final Device? device;
  final String? initialName;
  final String? initialAddress;
  final DeviceType? initialType;

  bool get isEditing => device != null;

  @override
  State<DeviceEditorPage> createState() => _DeviceEditorPageState();
}

class _DeviceEditorPageState extends State<DeviceEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late DeviceType _type;
  String? _icon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Device? device = widget.device;
    _nameController = TextEditingController(
      text: device?.name ?? widget.initialName ?? '',
    );
    _addressController = TextEditingController(
      text: device?.primaryAddress ?? widget.initialAddress ?? '',
    );
    _notesController = TextEditingController(text: device?.notes ?? '');
    _type = device?.deviceType ?? widget.initialType ?? DeviceType.other;
    _icon = device?.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final LanDeckRepository repository = AppScope.of(context);
    try {
      final Device saved;
      if (widget.isEditing) {
        saved = await repository.updateDevice(
          widget.device!.copyWith(
            name: _nameController.text,
            deviceType: _type,
            primaryAddress: _addressController.text,
            notes: () => _notesController.text,
            icon: () => _icon,
          ),
        );
      } else {
        saved = await repository.addDevice(
          name: _nameController.text,
          deviceType: _type,
          primaryAddress: _addressController.text,
          notes: _notesController.text,
          icon: _icon,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } on DeviceConflictException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppSnackBar(context, '保存设备失败：$error');
    }
  }

  String _iconLabel(String key) => switch (key) {
    'storage' => '存储',
    'router' => '路由',
    'computer' => '电脑',
    'server' => '服务器',
    'phone' => '手机',
    'media' => '影音',
    'home' => '家庭',
    'devices' => '通用',
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑设备' : '添加设备')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kFormPageMaxWidth),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  8,
                  AppSpacing.page,
                  32,
                ),
                children: <Widget>[
                  Text(
                    '设备地址是关联服务 URL 的基础。修改地址后，所有关联服务会自动更新。',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey<String>('device-name-field'),
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '设备名称',
                      hintText: '例如：书房 NAS',
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入设备名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey<String>('device-address-field'),
                    controller: _addressController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: '设备地址',
                      hintText: '192.168.1.10 或 nas.local',
                      helperText: '只填 IP / 主机名，不要包含 http://、端口或路径。',
                      helperMaxLines: 2,
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入设备 IP 或主机名';
                      }
                      if (normalizeDeviceAddress(value) == null) {
                        return '请输入有效的 IP 或主机名';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DeviceType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: '设备类型'),
                    items: DeviceType.values
                        .map(
                          (DeviceType type) => DropdownMenuItem<DeviceType>(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (DeviceType? value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('图标（可选）', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('自动'),
                        selected: _icon == null,
                        onSelected: (_) => setState(() => _icon = null),
                      ),
                      for (final MapEntry<String, IconData> entry
                          in deviceIconChoices.entries)
                        ChoiceChip(
                          avatar: Icon(entry.value, size: 18),
                          label: Text(_iconLabel(entry.key)),
                          selected: _icon == entry.key,
                          onSelected: (_) => setState(() => _icon = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      hintText: '例如：二楼弱电箱',
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const ValueKey<String>('device-save-button'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isEditing ? '保存修改' : '保存设备'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
