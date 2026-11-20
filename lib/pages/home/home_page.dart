import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../models/device_category.dart';
import '../../models/service.dart';
import '../../pages/services/service_editor_page.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/add_service_button.dart';
import 'widgets/all_services_section.dart';
import 'widgets/categories_section.dart';
import 'widgets/favorites_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_field.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenSettings,
    required this.onOpenDiscover,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDiscover;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _openService(Service service) {
    Navigator.of(context).pushNamed<void>(
      AppRoutes.webView,
      arguments: WebViewArguments(serviceId: service.id),
    );
  }

  void _openCategory(DeviceCategory category) {
    Navigator.of(context).pushNamed<void>(
      AppRoutes.category,
      arguments: CategoryPageArguments(category: category),
    );
  }

  Future<void> _handleAddService() async {
    final Service? saved = await Navigator.of(context).push<Service>(
      MaterialPageRoute<Service>(
        builder: (BuildContext context) => const ServiceEditorPage(),
      ),
    );
    if (saved != null && mounted) {
      showAppSnackBar(context, '已添加「${saved.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final List<Service> favorites = repository.favorites;
    final List<Service> visible = repository.searchServices(_query);
    final Map<DeviceCategory, int> counts = repository.categoryCounts;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              12,
              AppSpacing.page,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HomeHeader(
                  serviceCount: repository.services.length,
                  onlineCount: repository.onlineCount,
                  onOpenSettings: widget.onOpenSettings,
                ),
                const SizedBox(height: 18),
                HomeSearchField(
                  controller: _searchController,
                  onChanged: _handleSearchChanged,
                  onClear: _clearSearch,
                ),
                const SizedBox(height: 24),
                FavoritesSection(
                  services: favorites,
                  onOpenService: _openService,
                  onAddService: _handleAddService,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                CategoriesSection(
                  counts: counts,
                  onSelect: _openCategory,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                AllServicesSection(
                  services: visible,
                  query: _query,
                  deviceNameFor: repository.deviceNameFor,
                  onOpenService: _openService,
                  onClearSearch: _clearSearch,
                  onAddService: _handleAddService,
                  onScan: widget.onOpenDiscover,
                ),
                const SizedBox(height: 14),
                AddServiceButton(onTap: _handleAddService),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
