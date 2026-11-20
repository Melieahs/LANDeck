import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/url_utils.dart';
import '../../models/device.dart';
import '../../models/device_category.dart';
import '../../models/http_credential.dart';
import '../../models/scan_candidate.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../services/http_credential_store.dart';
import '../../widgets/service_icon.dart';
import '../devices/device_editor_page.dart';

/// Port-to-name hints. These are suggestions only; the name always stays
/// editable and no service is auto-detected.
const Map<int, String> _portSuggestions = <int, String>{
  80: 'HTTP Web 服务',
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
  9000: 'Portainer',
  9090: 'Web 管理界面',
  9091: '下载管理',
  9443: 'HTTPS Web 管理',
};

class ServiceEditorPage extends StatefulWidget {
  const ServiceEditorPage({
    super.key,
    this.service,
    this.candidate,
    this.initialDeviceId,
    this.initialCategory,
    this.quickMode = false,
  });

  final Service? service;
  final ScanCandidate? candidate;
  final String? initialDeviceId;
  final DeviceCategory? initialCategory;

  /// Quick mode is opened from a device detail page: the device is fixed and
  /// the user only needs a port/name.
  final bool quickMode;

  bool get isEditing => service != null;

  @override
  State<ServiceEditorPage> createState() => _ServiceEditorPageState();
}

class _ServiceEditorPageState extends State<ServiceEditorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _portController;
  late final TextEditingController _pathController;
  late final TextEditingController _customUrlController;

  late String _protocol;
  String? _deviceId;
  DeviceCategory? _category;
  ServiceGlyph? _icon;
  bool _favorite = false;
  bool _useCustomUrl = false;
  bool _saving = false;
  bool _autoName = false;
  bool _protocolEdited = false;
  String? _formError;
  List<HttpCredential> _credentials = const <HttpCredential>[];
  bool _credentialsLoading = false;

  @override
  void initState() {
    super.initState();
    final Service? service = widget.service;
    final ScanCandidate? candidate = widget.candidate;
    _deviceId = service?.deviceId ?? widget.initialDeviceId;
    _category = service?.category ?? widget.initialCategory;
    _icon = service?.icon;
    _favorite = service?.isFavorite ?? false;

    final Uri? candidateUri =
        candidate == null ? null : Uri.tryParse(candidate.url);
    _protocol = service?.protocol ??
        (candidateUri?.scheme == 'https' ? 'https' : 'http');
    _portController = TextEditingController(
      text: service?.port?.toString() ??
          (candidate == null ? '' : candidate.port.toString()),
    );
    _pathController = TextEditingController(
      text: service?.path ?? _candidatePath(candidateUri),
    );
    _customUrlController = TextEditingController(
      text: service?.customUrl ??
          (_deviceId == null ? candidate?.url ?? '' : ''),
    );
    _useCustomUrl = service?.hasCustomUrl ??
        (_deviceId == null && candidate != null);

    final String initialName = service?.name ?? candidate?.displayTitle ?? '';
    _nameController = TextEditingController(text: initialName);
    _autoName = initialName.trim().isEmpty;
    if (_autoName && _portController.text.isNotEmpty) {
      _nameController.text = _suggestionForPort(int.tryParse(_portController.text));
    }
    if (_deviceId != null) {
      _useCustomUrl = service?.hasCustomUrl ?? false;
    }
    if (widget.isEditing) {
      unawaited(_loadCredentials());
    }
  }

  Future<void> _loadCredentials() async {
    final Service? service = widget.service;
    if (service == null) {
      return;
    }
    setState(() => _credentialsLoading = true);
    final List<HttpCredential> credentials =
        await HttpCredentialStore.instance.credentialsFor(service.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _credentials = credentials;
      _credentialsLoading = false;
    });
  }

  Future<void> _deleteCredential(HttpCredential credential) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除登录凭据？'),
        content: Text(
          '将从本机删除 ${credential.username} 用于 '
          '${credential.host}（${credential.realm.isEmpty ? '默认认证域' : credential.realm}）'
          ' 的凭据。下次打开服务时需要重新认证。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || widget.service == null) {
      return;
    }
    await HttpCredentialStore.instance.deleteScope(
      widget.service!.id,
      host: credential.host,
      realm: credential.realm,
    );
    await _loadCredentials();
    if (mounted) {
      showAppSnackBar(context, '已删除保存的登录凭据');
    }
  }

  String? _candidatePath(Uri? uri) {
    if (uri == null) {
      return null;
    }
    if (uri.path.isEmpty || uri.path == '/') {
      return uri.hasQuery ? '?${uri.query}' : null;
    }
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portController.dispose();
    _pathController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  String _suggestionForPort(int? port) {
    if (port == null) {
      return '';
    }
    return _portSuggestions[port] ?? '端口 $port';
  }

  void _onPortChanged(String value) {
    final int? port = int.tryParse(value.trim());
    if (_autoName) {
      _nameController.text = _suggestionForPort(port);
    }
    if (!_protocolEdited &&
        (port == 443 || port == 5001 || port == 8443 || port == 8920 || port == 9443)) {
      _protocol = 'https';
    }
    setState(() {});
  }

  Future<void> _createDevice() async {
    final Device? device = await Navigator.of(context).push<Device>(
      MaterialPageRoute<Device>(
        builder: (BuildContext context) => const DeviceEditorPage(),
      ),
    );
    if (device != null && mounted) {
      setState(() {
        _deviceId = device.id;
        _useCustomUrl = false;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(_deviceId);
    if (_deviceId != null && device == null) {
      setState(() => _formError = '所属设备不存在或已被删除');
      return;
    }
    final bool useCustom = _deviceId == null || _useCustomUrl;
    final String? custom =
        useCustom ? _customUrlController.text.trim() : null;
    if (useCustom && (custom == null || custom.isEmpty)) {
      setState(() => _formError = '请输入完整 URL');
      return;
    }
    final int? port = _portController.text.trim().isEmpty
        ? null
        : int.tryParse(_portController.text.trim());
    if (_portController.text.trim().isNotEmpty && port == null) {
      setState(() => _formError = '端口必须是数字');
      return;
    }

    final ScanCandidate? candidate = widget.candidate;
    final ServiceStatus? scannedStatus =
        candidate != null && candidate.isConfirmed ? ServiceStatus.online : null;
    final DateTime? scannedAt = scannedStatus == null ? null : DateTime.now();

    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final Service saved;
      if (widget.isEditing) {
        saved = await repository.updateService(
          widget.service!.copyWith(
            name: _nameController.text.trim(),
            deviceId: () => _deviceId,
            protocol: _protocol,
            port: () => port,
            path: () => _pathController.text.trim(),
            customUrl: () => custom,
            category: () => _category,
            icon: () => _icon,
            isFavorite: _favorite,
            lastStatus: () => scannedStatus ?? widget.service!.lastStatus,
            lastCheckedAt: () => scannedAt ?? widget.service!.lastCheckedAt,
          ),
        );
      } else {
        saved = await repository.addService(
          name: _nameController.text.trim(),
          deviceId: _deviceId,
          protocol: _protocol,
          port: port,
          path: _pathController.text.trim(),
          customUrl: custom,
          category: _category,
          icon: _icon,
          isFavorite: _favorite,
          lastStatus: scannedStatus,
          lastCheckedAt: scannedAt,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } on ServiceConflictException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = error.message;
        _saving = false;
      });
      _formKey.currentState?.validate();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppSnackBar(context, '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final Device? device = repository.deviceById(_deviceId);
    final bool customActive = _deviceId == null || _useCustomUrl;
    final String preview = _previewUrl(device);
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
                    _EditorHeader(
                      title: widget.isEditing
                          ? '编辑服务'
                          : (widget.quickMode ? '添加服务' : '添加服务'),
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 18),
                    if (widget.candidate != null) ...<Widget>[
                      _ScanContextCard(candidate: widget.candidate!),
                      const SizedBox(height: 15),
                    ],
                    if (widget.quickMode && device != null) ...<Widget>[
                      _DeviceBanner(device: device),
                      const SizedBox(height: 16),
                    ],
                    _FieldLabel('服务名称', required: true),
                    const SizedBox(height: 7),
                    TextFormField(
                      key: const ValueKey<String>('service-name-field'),
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: widget.quickMode ? '例如：Jellyfin' : '例如：飞牛 NAS',
                        helperText: widget.quickMode
                            ? '根据端口自动建议，可随时修改'
                            : null,
                      ),
                      onChanged: (_) => _autoName = false,
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入服务名称';
                        }
                        return null;
                      },
                    ),
                    if (!widget.quickMode) ...<Widget>[
                      const SizedBox(height: 16),
                      _FieldLabel('所属设备'),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(
                          'service-device-field-${_deviceId ?? 'none'}-${repository.devices.length}',
                        ),
                        initialValue: _deviceId ?? _noneValue,
                        decoration: const InputDecoration(
                          hintText: '未分配设备',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: _noneValue,
                            child: Text('未分配设备（使用完整 URL）'),
                          ),
                          ...repository.devices.map(
                            (Device device) => DropdownMenuItem<String>(
                              value: device.id,
                              child: Text(
                                '${device.name} · ${device.primaryAddress}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _deviceId = value == _noneValue ? null : value;
                            _useCustomUrl = _deviceId == null
                                ? true
                                : false;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          TextButton.icon(
                            onPressed: _createDevice,
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: const Text('新建设备'),
                          ),
                          if (repository.devices.isEmpty)
                            const Expanded(
                              child: Text(
                                '还没有设备，先创建设备即可免填 IP。',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (device != null) ...<Widget>[
                      const SizedBox(height: 6),
                      _FieldLabel('协议'),
                      const SizedBox(height: 7),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'http',
                            label: Text('HTTP'),
                          ),
                          ButtonSegment<String>(
                            value: 'https',
                            label: Text('HTTPS'),
                          ),
                        ],
                        selected: <String>{_protocol},
                        showSelectedIcon: false,
                        onSelectionChanged: (Set<String> values) {
                          setState(() {
                            _protocol = values.first;
                            _protocolEdited = true;
                          });
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _FieldLabel('端口'),
                                const SizedBox(height: 7),
                                TextFormField(
                                  key: const ValueKey<String>('service-port-field'),
                                  controller: _portController,
                                  autofocus: widget.quickMode,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    hintText: '例如 8096',
                                    helperText: _portHint(),
                                    helperMaxLines: 2,
                                  ),
                                  onChanged: _onPortChanged,
                                  validator: (String? value) {
                                    final String text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return null;
                                    }
                                    final int? port = int.tryParse(text);
                                    if (port == null || port < 1 || port > 65535) {
                                      return '端口需在 1–65535';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _FieldLabel('路径'),
                                const SizedBox(height: 7),
                                TextFormField(
                                  key: const ValueKey<String>('service-path-field'),
                                  controller: _pathController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    hintText: '/web（可选）',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!widget.quickMode) ...<Widget>[
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          value: _useCustomUrl,
                          onChanged: (bool value) => setState(() {
                            _useCustomUrl = value;
                          }),
                          title: const Text(
                            '使用自定义 URL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            '反向代理、独立域名或复杂参数时开启。',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          activeThumbColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                    if (customActive) ...<Widget>[
                      const SizedBox(height: 14),
                      _FieldLabel('完整 URL', required: true),
                      const SizedBox(height: 7),
                      TextFormField(
                        key: const ValueKey<String>('service-url-field'),
                        controller: _customUrlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          hintText: 'http://192.168.1.10:8080/docker',
                          helperText: '支持 IP、域名、端口、路径与查询参数。',
                          helperMaxLines: 2,
                        ),
                        onChanged: (_) => setState(() => _formError = null),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return '请输入完整 URL';
                          }
                          if (normalizeHttpUrl(text, defaultScheme: _protocol) ==
                              null) {
                            return '请输入有效的 HTTP 或 HTTPS 地址';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (device != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _UrlPreview(url: preview),
                    ],
                    const SizedBox(height: 18),
                    _FieldLabel('服务分类'),
                    const SizedBox(height: 7),
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>('service-category-field'),
                      initialValue: _category?.name ?? _noneValue,
                      decoration: const InputDecoration(hintText: '未分类'),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: _noneValue,
                          child: Text('未分类'),
                        ),
                        ...DeviceCategory.values
                            .where(
                              (DeviceCategory category) =>
                                  category != DeviceCategory.all,
                            )
                            .map(
                              (DeviceCategory category) =>
                                  DropdownMenuItem<String>(
                                    value: category.name,
                                    child: Text(category.label),
                                  ),
                            ),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _category = value == _noneValue
                              ? null
                              : DeviceCategory.values.firstWhere(
                                  (DeviceCategory category) =>
                                      category.name == value,
                                );
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel('图标'),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _GlyphChoice(
                          label: '自动',
                          icon: Icons.auto_awesome_rounded,
                          selected: _icon == null,
                          onTap: () => setState(() => _icon = null),
                        ),
                        ...ServiceGlyph.values.map(
                          (ServiceGlyph glyph) => _GlyphChoice(
                            label: _glyphLabel(glyph),
                            icon: iconForGlyph(glyph),
                            selected: _icon == glyph,
                            onTap: () => setState(() => _icon = glyph),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile.adaptive(
                        value: _favorite,
                        onChanged: (bool value) =>
                            setState(() => _favorite = value),
                        title: const Text(
                          '加入收藏',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          '收藏会显示在首页顶部。',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        activeThumbColor: AppColors.accent,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                    if (widget.isEditing) ...<Widget>[
                      const SizedBox(height: 16),
                      _SavedCredentialsCard(
                        credentials: _credentials,
                        loading: _credentialsLoading,
                        onDelete: _deleteCredential,
                      ),
                    ],
                    if (_formError != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _formError!,
                        key: const ValueKey<String>('service-form-error'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFFF8A96),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: const ValueKey<String>('service-save-button'),
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
                                widget.isEditing ? '保存修改' : '保存服务',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        '服务会保存在本机数据库中，不会上传到云端。',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
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

  String _portHint() {
    final int? port = int.tryParse(_portController.text.trim());
    if (port == null) {
      return '留空则使用协议默认端口';
    }
    final String? suggestion = _portSuggestions[port];
    if (suggestion == null) {
      return '端口 $port（可修改名称）';
    }
    if (port == 9000) {
      return '建议名称：$suggestion（可能与其他服务冲突）';
    }
    return '建议名称：$suggestion';
  }

  String _previewUrl(Device? device) {
    final bool custom = _deviceId == null || _useCustomUrl;
    if (custom) {
      final String text = _customUrlController.text.trim();
      return normalizeHttpUrl(text, defaultScheme: _protocol) ??
          (text.isEmpty ? '填写完整 URL 后显示' : text);
    }
    if (device == null) {
      return '选择设备后自动生成';
    }
    final int? port = _portController.text.trim().isEmpty
        ? null
        : int.tryParse(_portController.text.trim());
    return buildServiceUrl(
      address: device.primaryAddress,
      protocol: _protocol,
      port: port,
      path: _pathController.text.trim(),
    );
  }

  static const String _noneValue = '__none__';

  String _glyphLabel(ServiceGlyph glyph) => switch (glyph) {
    ServiceGlyph.nas => 'NAS',
    ServiceGlyph.router => '路由',
    ServiceGlyph.docker => '容器',
    ServiceGlyph.media => '影音',
    ServiceGlyph.download => '下载',
    ServiceGlyph.home => '家居',
    ServiceGlyph.generic => '通用',
  };
}

class _SavedCredentialsCard extends StatelessWidget {
  const _SavedCredentialsCard({
    required this.credentials,
    required this.loading,
    required this.onDelete,
  });

  final List<HttpCredential> credentials;
  final bool loading;
  final ValueChanged<HttpCredential> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.key_rounded, size: 16, color: AppColors.accent),
              SizedBox(width: 7),
              Text(
                'HTTP 登录凭据',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            '仅在 WebView 中主动勾选「记住登录信息」时保存。'
            '凭据使用 Android Keystore 加密，并与本服务、认证域绑定。',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          if (loading) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (credentials.isEmpty) ...<Widget>[
            const SizedBox(height: 9),
            const Text(
              '尚未保存凭据。',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            ...credentials.asMap().entries.map(
              (MapEntry<int, HttpCredential> entry) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.value.username,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${entry.value.host} · '
                            '${entry.value.realm.isEmpty ? '默认认证域' : entry.value.realm}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('delete-credential-${entry.key}'),
                      tooltip: '删除凭据',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onDelete(entry.value),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

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

class _DeviceBanner extends StatelessWidget {
  const _DeviceBanner({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.devices_other_rounded, size: 17,
              color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '添加到 ${device.name} · ${device.primaryAddress}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlPreview extends StatelessWidget {
  const _UrlPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            '访问地址',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              key: const ValueKey<String>('service-url-preview'),
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanContextCard extends StatelessWidget {
  const _ScanContextCard({required this.candidate});

  final ScanCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final bool confirmed = candidate.isConfirmed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            confirmed ? Icons.verified_rounded : Icons.help_outline_rounded,
            size: 17,
            color: confirmed ? AppColors.online : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              confirmed
                  ? '来自局域网扫描 · ${candidate.sourceLabel}，保存前请确认名称与地址。'
                  : '该端口开放但未确认 Web 响应，保存后可能无法打开。',
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlyphChoice extends StatelessWidget {
  const _GlyphChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
