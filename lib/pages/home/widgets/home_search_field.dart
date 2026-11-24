import 'package:flutter/material.dart';

/// Home entry point for the dedicated search page.
class HomeSearchField extends StatelessWidget {
  const HomeSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        return SearchBar(
          key: const ValueKey<String>('home-search-field'),
          controller: controller,
          hintText: '搜索服务、设备或 IP',
          leading: const Icon(Icons.search_rounded),
          trailing: <Widget>[
            if (value.text.isNotEmpty)
              IconButton(
                onPressed: onClear,
                tooltip: '清除搜索',
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          elevation: const WidgetStatePropertyAll<double>(0),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.only(left: 18, right: 8),
          ),
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
        );
      },
    );
  }
}
