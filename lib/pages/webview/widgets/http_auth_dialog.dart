import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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

/// Material 3 in-app replacement for the system HTTP authentication prompt.
///
/// The caller keeps the pending [HttpAuthRequest] alive and resumes it after
/// this dialog closes, so the page is never rebuilt.
Future<HttpAuthResult?> showHttpAuthDialog(
  BuildContext context, {
  required String serviceName,
  required String address,
  required String host,
  required String realm,
  String? initialUsername,
  String? errorText,
}) {
  return showGeneralDialog<HttpAuthResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '身份验证',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => _HttpAuthDialog(
          serviceName: serviceName,
          address: address,
          host: host,
          realm: realm,
          initialUsername: initialUsername,
          errorText: errorText,
        ),
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) => FadeTransition(opacity: animation, child: child),
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

class _HttpAuthDialogState extends State<_HttpAuthDialog>
    with WidgetsBindingObserver {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscure = true;
  bool _remember = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _passwordController = TextEditingController();
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    TextInput.finishAutofillContext();
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardOpen = keyboardInset > 0;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double maxHeight = (screenHeight - keyboardInset - 48)
        .clamp(240.0, screenHeight)
        .toDouble();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardInset),
      child: Center(
        child: ConstrainedBox(
          key: const ValueKey<String>('http-auth-dialog'),
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 6,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      keyboardOpen ? 16 : 24,
                      24,
                      8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (!keyboardOpen) ...<Widget>[
                          Icon(
                            Icons.lock_outline_rounded,
                            color: scheme.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          '需要身份验证',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: keyboardOpen ? 8 : 16),
                        Text(
                          widget.serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            Chip(
                              label: Text(widget.host),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(
                                widget.realm.isEmpty ? '默认认证域' : widget.realm,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AutofillGroup(
                          child: Column(
                            children: <Widget>[
                              TextField(
                                key: const ValueKey<String>(
                                  'http-auth-username',
                                ),
                                controller: _usernameController,
                                autofocus: false,
                                autofillHints: const <String>[
                                  AutofillHints.username,
                                ],
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: '用户名',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                key: const ValueKey<String>(
                                  'http-auth-password',
                                ),
                                controller: _passwordController,
                                obscureText: _obscure,
                                autofillHints: const <String>[
                                  AutofillHints.password,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: '密码',
                                  prefixIcon: const Icon(Icons.key_rounded),
                                  suffixIcon: IconButton(
                                    key: const ValueKey<String>(
                                      'http-auth-toggle-password',
                                    ),
                                    tooltip: _obscure ? '显示密码' : '隐藏密码',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (error.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            error,
                            key: const ValueKey<String>('http-auth-error'),
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                        const SizedBox(height: 4),
                        CheckboxListTile(
                          key: const ValueKey<String>('http-auth-remember'),
                          value: _remember,
                          onChanged: (bool? value) =>
                              setState(() => _remember = value ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('记住登录信息'),
                          subtitle: const Text(
                            '默认关闭。开启后使用 Android Keystore 加密保存。',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        key: const ValueKey<String>('http-auth-cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const ValueKey<String>('http-auth-submit'),
                        onPressed: _submit,
                        child: const Text('登录'),
                      ),
                    ],
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
