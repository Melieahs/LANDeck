import 'package:material_ui/material_ui.dart';

import 'core/app_scope.dart';
import 'core/theme/app_theme.dart';
import 'pages/main_shell.dart';
import 'repositories/service_repository.dart';
import 'routes/app_router.dart';

class LanDeckApp extends StatelessWidget {
  const LanDeckApp({super.key, required this.repository});

  final LanDeckRepository repository;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: repository,
      child: MaterialApp(
        title: 'LANDeck',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const MainShell(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
