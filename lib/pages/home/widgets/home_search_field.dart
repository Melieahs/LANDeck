import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

class HomeSearchField extends StatefulWidget {
  const HomeSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends State<HomeSearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? AppColors.accent.withValues(alpha: 0.55)
              : AppColors.border,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.accent,
        style: const TextStyle(
          fontSize: 13.5,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索服务、设备或 IP',
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 9),
            child: Icon(
              Icons.search_rounded,
              size: 19,
              color: _focused ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (BuildContext context, TextEditingValue value, Widget? child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: widget.onClear,
                tooltip: '清除搜索',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              );
            },
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
