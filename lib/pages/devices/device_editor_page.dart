import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/url_utils.dart';
import '../../models/device.dart';
import '../../repositories/service_repository.dart';

class DeviceEditorPage extends StatefulWidget {
  const DeviceEditorPage({super.key, this.device});

  final Device? device;

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Device? device = widget.device;
    _nameController = TextEditingController(text: device?.name ?? '');
    _addressController = TextEditingController(
      text: device?.primaryAddress ?? '',
    );
    _notesController = TextEditingController(text: device?.notes ?? '');
    _type = device?.deviceType ?? DeviceType.nas;
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
          ),
        );
      } else {
        saved = await repository.addDevice(
          name: _nameController.text,
          deviceType: _type,
          primaryAddress: _addressController.text,
          notes: _notesController.text,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  4,
                  AppSpacing.page,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.isEditing ? '编辑设备' : '添加设备',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '设备地址是关联服务 URL 的基础。修改地址后，所有关联服务会自动更新。',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _Label('设备名称', required: true),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey<String>('device-name-field'),
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
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
                    const _Label('设备地址', required: true),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey<String>('device-address-field'),
                      controller: _addressController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
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
                    const _Label('设备类型'),
                    const SizedBox(height: 7),
                    DropdownButtonFormField<DeviceType>(
                      initialValue: _type,
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
                    const _Label('备注'),
                    const SizedBox(height: 7),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '可选，例如：二楼弱电箱',
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey<String>('device-save-button'),
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: const Color(0xFF04101F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF04101F),
                                ),
                              )
                            : Text(
                                widget.isEditing ? '保存修改' : '保存设备',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        children: <InlineSpan>[
          if (required)
            const TextSpan(
              text: '  *',
              style: TextStyle(color: AppColors.accent),
            ),
        ],
      ),
    );
  }
}
