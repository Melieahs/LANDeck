import 'package:material_ui/material_ui.dart';

import '../models/device_category.dart';
import '../pages/category/category_page.dart';
import '../pages/main_shell.dart';
import '../pages/service/service_viewer_page.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String discover = '/discover';
  static const String settings = '/settings';
  static const String category = '/category';
  static const String webView = '/webview';
}

class CategoryPageArguments {
  const CategoryPageArguments({required this.category});

  final DeviceCategory category;
}

class WebViewArguments {
  const WebViewArguments({required this.serviceId});

  final String serviceId;
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.category) {
      final Object? arguments = settings.arguments;
      final DeviceCategory category = arguments is CategoryPageArguments
          ? arguments.category
          : DeviceCategory.all;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (BuildContext context) => CategoryPage(category: category),
      );
    }

    if (settings.name == AppRoutes.webView) {
      final Object? arguments = settings.arguments;
      if (arguments is WebViewArguments) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) =>
              ServiceViewerPage(serviceId: arguments.serviceId),
        );
      }
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => const MainShell(),
    );
  }
}
