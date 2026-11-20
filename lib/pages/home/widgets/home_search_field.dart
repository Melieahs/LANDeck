import 'package:material_ui/material_ui.dart';

/// Material 3 search bar. Results are filtered inline on the home page.
class HomeSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        return SearchBar(
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
            EdgeInsets.symmetric(horizontal: 8),
          ),
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
        );
      },
    );
  }
}
