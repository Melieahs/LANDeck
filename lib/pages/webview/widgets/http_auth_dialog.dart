import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

class HttpAuthResult {
  const HttpAuthResult({
    required this.username,
    required this.password,
    required this.remember,
  });

  final String username;
  final String password;
  final bool remember;
}

/// Dark, app-native replacement for the system HTTP authentication prompt.
///
/// The dialog deliberately does not rebuild the WebView; the caller keeps the
/// pending [HttpAuthRequest] alive and resumes it after this dialog closes.
Future<HttpAuthResult?> showHttpAuthDialog(
  BuildContext context, {
  required String serviceName,
  required String address,
  required String host,
  required String realm,
  String? initialUsername,
  String? errorText,
}) {
  return showDialog<HttpAuthResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _HttpAuthDialog(
      serviceName: serviceName,
      address: address,
      host: host,
      realm: realm,
      initialUsername: initialUsername,
      errorText: errorText,
    ),
  );
}

class _HttpAuthDialog extends StatefulWidget {
  const _HttpAuthDialog({
    required this.serviceName,
    required this.address,
    required this.host,
    required this.realm,
    this.initialUsername,
    this.errorText,
  });

  final String serviceName;
  final String address;
  final String host;
  final String realm;
  final String? initialUsername;
  final String? errorText;

  @override
  State<_HttpAuthDialog> createState() => _HttpAuthDialogState();
}

class _HttpAuthDialogState extends State<_HttpAuthDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscure = true;
  bool _remember = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final String username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _localError = '请输入用户名');
      return;
    }
    Navigator.of(context).pop(
      HttpAuthResult(
        username: username,
        password: _passwordController.text,
        remember: _remember,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String error = _localError ?? widget.errorText ?? '';
    return Dialog(
      key: const ValueKey<String>('http-auth-dialog'),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 21,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '需要身份验证',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '该服务要求输入用户名和密码',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ServiceContext(
                serviceName: widget.serviceName,
                address: widget.address,
                host: widget.host,
                realm: widget.realm,
              ),
              const SizedBox(height: 16),
              const Text(
                '用户名',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey<String>('http-auth-username'),
                controller: _usernameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: '请输入用户名',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '密码',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey<String>('http-auth-password'),
                controller: _passwordController,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '请输入密码',
                  prefixIcon: const Icon(Icons.key_rounded, size: 18),
                  suffixIcon: IconButton(
                    key: const ValueKey<String>('http-auth-toggle-password'),
                    tooltip: _obscure ? '显示密码' : '隐藏密码',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF5C6C),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0x33FF5C6C)),
                  ),
                  child: Text(
                    error,
                    key: const ValueKey<String>('http-auth-error'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFF9AA4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Material(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                child: CheckboxListTile(
                  key: const ValueKey<String>('http-auth-remember'),
                  value: _remember,
                  onChanged: (bool? value) =>
                      setState(() => _remember = value ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  activeColor: AppColors.accent,
                  checkColor: const Color(0xFF04101F),
                  title: const Text(
                    '记住登录信息',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    '默认关闭。开启后使用 Android Keystore 加密保存。',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey<String>('http-auth-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('http-auth-submit'),
                      onPressed: _submit,
                      child: const Text('登录'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceContext extends StatelessWidget {
  const _ServiceContext({
    required this.serviceName,
    required this.address,
    required this.host,
    required this.realm,
  });

  final String serviceName;
  final String address;
  final String host;
  final String realm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            serviceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: <Widget>[
              _Pill(label: host),
              _Pill(label: realm.isEmpty ? '默认认证域' : realm),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9.5, color: AppColors.accent),
      ),
    );
  }
}
