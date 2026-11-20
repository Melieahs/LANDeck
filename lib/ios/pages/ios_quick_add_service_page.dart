import 'package:cupertino_ui/cupertino_ui.dart';

import '../../core/app_scope.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';

class IosQuickAddServicePage extends StatefulWidget {
  const IosQuickAddServicePage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.deviceAddress,
  });

  final String deviceId;
  final String deviceName;
  final String deviceAddress;

  @override
  State<IosQuickAddServicePage> createState() => _IosQuickAddServicePageState();
}

class _IosQuickAddServicePageState extends State<IosQuickAddServicePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _port = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _path = TextEditingController();
  String _protocol = 'http';
  bool _favorite = false;
  bool _nameEdited = false;
  bool _saving = false;

  static const Map<int, String> _suggestions = <int, String>{
    80: 'Web 服务',
    443: 'HTTPS Web 服务',
    3000: 'Web 应用',
    5000: 'NAS 管理',
    5001: 'NAS 管理（HTTPS）',
    7878: 'Web 管理界面',
    8000: 'Web 服务',
    8080: 'Web 服务',
    8096: 'Jellyfin',
    8443: 'HTTPS Web 管理',
    8920: '影音服务',
    9000: 'Portainer（可能冲突）',
    9090: 'Web 管理界面',
    9091: '下载管理',
    9443: 'HTTPS Web 管理',
  };

  @override
  void dispose() {
    _port.dispose();
    _name.dispose();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('添加服务'),
        trailing: CupertinoButton(
          key: const ValueKey<String>('ios-service-save'),
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
              CupertinoListSection.insetGrouped(
                header: const Text('所属设备'),
                children: <Widget>[
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.desktopcomputer),
                    title: Text(widget.deviceName),
                    subtitle: Text(widget.deviceAddress),
                    additionalInfo: const Text('自动关联'),
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                header: const Text('服务'),
                children: <Widget>[
                  CupertinoTextFormFieldRow(
                    key: const ValueKey<String>('ios-service-port'),
                    controller: _port,
                    prefix: const Text('端口'),
                    placeholder: '例如 8096',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: _onPortChanged,
                    validator: (String? value) {
                      final int? port = int.tryParse(value?.trim() ?? '');
                      if (port == null || port < 1 || port > 65535) {
                        return '请输入 1–65535 之间的端口';
                      }
                      return null;
                    },
                  ),
                  CupertinoFormRow(
                    prefix: const Text('协议'),
                    child: SizedBox(
                      width: 150,
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: _protocol,
                        children: const <String, Widget>{
                          'http': Text('HTTP'),
                          'https': Text('HTTPS'),
                        },
                        onValueChanged: (String? value) {
                          if (value != null) {
                            setState(() => _protocol = value);
                          }
                        },
                      ),
                    ),
                  ),
                  CupertinoTextFormFieldRow(
                    key: const ValueKey<String>('ios-service-name'),
                    controller: _name,
                    prefix: const Text('名称'),
                    placeholder: '可自动建议，也可以修改',
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _nameEdited = true,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入服务名称';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _path,
                    prefix: const Text('路径'),
                    placeholder: '可选，例如 /web',
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                children: <Widget>[
                  CupertinoFormRow(
                    prefix: const Text('收藏'),
                    child: CupertinoSwitch(
                      value: _favorite,
                      onChanged: (bool value) =>
                          setState(() => _favorite = value),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
                child: Text(
                  '将生成 $_protocol://${widget.deviceAddress}${_port.text.trim().isEmpty ? '' : ':${_port.text.trim()}'}${_path.text.trim().isEmpty ? '' : (_path.text.trim().startsWith('/') ? _path.text.trim() : '/${_path.text.trim()}')}',
                  style: const TextStyle(
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

  void _onPortChanged(String value) {
    final int? port = int.tryParse(value);
    if (port == null) {
      return;
    }
    if (!_nameEdited) {
      _name.text = _suggestions[port] ?? '端口 $port';
    }
    if (port == 443 || port == 5001 || port == 8443 || port == 8920 || port == 9443) {
      _protocol = 'https';
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final int port = int.parse(_port.text.trim());
    setState(() => _saving = true);
    final LanDeckRepository repository = AppScope.of(context);
    try {
      await repository.addDeviceService(
        deviceId: widget.deviceId,
        name: _name.text.trim(),
        port: port,
        protocol: _protocol,
        path: _path.text.trim().isEmpty ? null : _path.text.trim(),
        icon: ServiceGlyph.generic,
        isFavorite: _favorite,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ServiceConflictException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        await _message('无法添加服务', error.message);
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
