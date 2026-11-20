import 'package:material_ui/material_ui.dart';

class SortChoice<T> {
  const SortChoice({required this.value, required this.label});

  final T value;
  final String label;
}

/// Small Material 3 overflow menu used by the home modules.
class SortMenu<T> extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.current,
    required this.choices,
    required this.onSelected,
    this.tooltip = '排序',
  });

  final T current;
  final List<SortChoice<T>> choices;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: const Icon(Icons.sort_rounded),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
        for (final SortChoice<T> choice in choices)
          CheckedPopupMenuItem<T>(
            value: choice.value,
            checked: choice.value == current,
            child: Text(choice.label),
          ),
      ],
    );
  }
}
