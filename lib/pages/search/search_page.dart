import 'package:material_ui/material_ui.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/device.dart';
import '../../models/service.dart';
import '../../pages/devices/device_detail_page.dart';
import '../../repositories/service_repository.dart';
import '../../routes/app_router.dart';
import '../../widgets/section_header.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/service_list_tile.dart';

/// Dedicated search surface reached from the home search bar.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    FocusScope.of(context).unfocus();
    setState(() => _query = value.trim());
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final LanDeckRepository repository = AppScope.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Service> services = _query.isEmpty
        ? const <Service>[]
        : repository.searchServices(_query);
    final String needle = _query.toLowerCase();
    final List<Device> devices = _query.isEmpty
        ? const <Device>[]
        : repository.devices
              .where(
                (Device device) =>
                    device.name.toLowerCase().contains(needle) ||
                    device.primaryAddress.toLowerCase().contains(needle) ||
                    device.deviceType.label.toLowerCase().contains(needle),
              )
              .toList();

    return Scaffold(
      key: const ValueKey<String>('search-page'),
      appBar: AppBar(title: const Text('搜索')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                8,
                AppSpacing.page,
                40,
              ),
              children: <Widget>[
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder:
                      (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? _,
                      ) {
                        return SearchBar(
                          key: const ValueKey<String>('search-field'),
                          controller: _controller,
                          autoFocus: widget.initialQuery.trim().isEmpty,
                          hintText: '搜索服务、设备或 IP',
                          leading: const Icon(Icons.search_rounded),
                          trailing: <Widget>[
                            if (value.text.isNotEmpty)
                              IconButton(
                                onPressed: _clear,
                                tooltip: '清除搜索',
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                          elevation: const WidgetStatePropertyAll<double>(0),
                          padding:
                              const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                                EdgeInsets.only(left: 18, right: 8),
                              ),
                          onSubmitted: _submit,
                          textInputAction: TextInputAction.search,
                        );
                      },
                ),
                const SizedBox(height: 20),
                if (_query.isEmpty)
                  _SearchHint(scheme: scheme)
                else if (services.isEmpty && devices.isEmpty)
                  _NoSearchResult(query: _query, scheme: scheme)
                else ...<Widget>[
                  if (devices.isNotEmpty) ...<Widget>[
                    SectionHeader(title: '设备', trailing: '${devices.length} 个'),
                    Card.outlined(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < devices.length; i++) ...<Widget>[
                            if (i > 0) const Divider(height: 1),
                            _DeviceResult(
                              device: devices[i],
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        DeviceDetailPage(
                                          deviceId: devices[i].id,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (services.isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: '服务',
                      trailing: '${services.length} 个',
                    ),
                    Card.outlined(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < services.length; i++) ...<Widget>[
                            if (i > 0) const Divider(height: 1),
                            ServiceListTile(
                              service: services[i],
                              deviceName: repository.deviceNameFor(services[i]),
                              onTap: () {
                                Navigator.of(context).pushNamed<void>(
                                  AppRoutes.webView,
                                  arguments: WebViewArguments(
                                    serviceId: services[i].id,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceResult extends StatelessWidget {
  const _DeviceResult({required this.device, required this.onTap});

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      leading: ServiceIconBadge(icon: iconForDevice(device)),
      title: Text(device.name),
      subtitle: Text('${device.deviceType.label} · ${device.addressLabel}'),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.manage_search_rounded,
            size: 44,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '输入服务名称、设备或 IP 地址',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult({required this.query, required this.scheme});

  final String query;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到与「$query」匹配的结果',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
