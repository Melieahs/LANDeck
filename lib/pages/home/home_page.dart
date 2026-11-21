import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/feedback.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../pages/devices/device_detail_page.dart';
import '../../pages/devices/device_editor_page.dart';
import '../../pages/devices/devices_page.dart';
import '../../pages/search/search_page.dart';
import '../../pages/services/service_editor_page.dart';
import '../../pages/services/services_page.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import 'widgets/all_services_section.dart';
import 'widgets/devices_section.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _submitSearch(String value) {
    final String query = value.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SearchPage(initialQuery: query),
      ),
    );
  }

  void _openService(Service service) {
    Navigator.of(context).pushNamed<void>(
      AppRoutes.webView,
      arguments: WebViewArguments(serviceId: service.id),
    );
  }

  void _openDevice(Device device) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DeviceDetailPage(deviceId: device.id),
      ),
    );
  }

  void _openServices() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const ServicesPage(),
      ),
    );
  }

  void _openDevices() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const DevicesPage(),
      ),
    );
  }

  Future<void> _handleAddDevice() async {
    final Device? saved = await Navigator.of(context).push<Device>(
      MaterialPageRoute<Device>(
        builder: (BuildContext context) => const DeviceEditorPage(),
      ),
    );
    if (saved != null && mounted) {
      showAppSnackBar(context, '已添加设备「${saved.name}」');
    }
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
    final List<Service> visible = repository.services;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LANDeck'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('home-add-service'),
            onPressed: _handleAddService,
            tooltip: '添加服务',
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('home-settings'),
            onPressed: widget.onOpenSettings,
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  HomeSearchField(
                    controller: _searchController,
                    onSubmitted: _submitSearch,
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: 20),
                  HomeHeader(
                    serviceCount: repository.services.length,
                    deviceCount: repository.devices.length,
                    onlineCount: repository.onlineCount,
                    onOpenServices: _openServices,
                    onOpenDevices: _openDevices,
                  ),
                  const SizedBox(height: 24),
                  FavoritesSection(
                    services: favorites,
                    deviceNameFor: repository.deviceNameFor,
                    onOpenService: _openService,
                    onAddService: _handleAddService,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  DevicesSection(
                    devices: repository.devices,
                    serviceCountForDevice: (Device device) =>
                        repository.serviceCountForDevice(device),
                    onOpenDevice: _openDevice,
                    onManage: _openDevices,
                    onAddDevice: _handleAddDevice,
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  AllServicesSection(
                    services: visible,
                    query: '',
                    deviceNameFor: repository.deviceNameFor,
                    devices: repository.devices,
                    onOpenService: _openService,
                    onClearSearch: _clearSearch,
                    onAddService: _handleAddService,
                    onScan: widget.onOpenDiscover,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
