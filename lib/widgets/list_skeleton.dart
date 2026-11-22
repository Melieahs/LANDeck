import 'package:material_ui/material_ui.dart';

/// A pulsing placeholder shown while a list is loading.
///
/// Keeps the layout stable so content does not jump when the real rows arrive.
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({
    super.key,
    this.rows = 4,
    this.rowHeight = 64,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 32),
  });

  final int rows;
  final double rowHeight;
  final EdgeInsets padding;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color block = scheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: widget.padding,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < widget.rows; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            FractionallySizedBox(
                              widthFactor: 0.55,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FractionallySizedBox(
                              widthFactor: 0.32,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
