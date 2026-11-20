import 'package:material_ui/material_ui.dart';

import '../repositories/service_repository.dart';

/// Exposes the single [LanDeckRepository] to every route and page.
class AppScope extends InheritedNotifier<LanDeckRepository> {
  const AppScope({
    super.key,
    required LanDeckRepository repository,
    required super.child,
  }) : super(notifier: repository);

  static LanDeckRepository of(BuildContext context) {
    final AppScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context');
    return scope!.notifier!;
  }

  static LanDeckRepository? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
  }
}
