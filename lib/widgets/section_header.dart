import 'package:material_ui/material_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.action,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? trailing;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: text.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (action != null) ...<Widget>[const SizedBox(width: 4), action!],
        ],
      ),
    );
  }
}
