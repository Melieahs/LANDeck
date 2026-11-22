import '../core/utils/url_utils.dart';
import 'device_category.dart';
import 'service_mode.dart';

/// Availability of a service as reported by the last real check.
enum ServiceStatus { online, offline }

/// How saved web credentials are used when a login page appears.
enum PasswordFillMode {
  /// Fill the default account without asking.
  auto,

  /// Ask which saved account to fill before touching the form.
  ask,

  /// Never fill automatically; the user can still fill from the menu.
  off,
}

extension PasswordFillModeLabel on PasswordFillMode {
  String get label => switch (this) {
    PasswordFillMode.auto => '自动填充',
    PasswordFillMode.ask => '填充前先选择',
    PasswordFillMode.off => '不自动填充',
  };

  String get description => switch (this) {
    PasswordFillMode.auto => '页面出现登录表单时，直接用默认账号填写。',
    PasswordFillMode.ask => '每次出现登录表单时，先让你选择要用的账号。',
    PasswordFillMode.off => '不自动填写，仍可在服务更多菜单里手动填充。',
  };
}

/// Visual glyph families used by the shared service icon widget.
///
/// Kept free of Flutter imports so the data layer stays presentation agnostic.
enum ServiceGlyph { nas, router, docker, media, download, home, generic }

/// A user-added web service inside the local network.
///
/// A service can either be linked to a [deviceId] (the URL is composed from the
/// device address, protocol, port and path) or keep a [customUrl] for reverse
/// proxies and other exceptions. [deviceAddress] is a transient value resolved
/// by the repository and is never persisted.
///
/// [lastStatus] stays null until a real scan or a WebView load has confirmed
/// reachability, so the UI never invents an online/offline state.
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.protocol = 'http',
    this.port,
    this.path,
    this.customUrl,
    this.deviceAddress,
    this.category,
    this.icon,
    this.isFavorite = false,
    this.sortOrder = 0,
    this.favoriteSortOrder,
    this.healthCheckEnabled = false,
    this.lastStatus,
    this.lastCheckedAt,
    this.lastOpenedAt,
    this.nativeModuleId,
    this.defaultMode = ServiceMode.web,
    this.passwordFillMode = PasswordFillMode.auto,
    this.defaultCredentialUsername,
  });

  final String id;
  final String name;
  final String? deviceId;

  /// `http` or `https`.
  final String protocol;
  final int? port;

  /// Optional path, e.g. `/web` or `/web?tab=1`.
  final String? path;

  /// Full URL override for reverse-proxy / special cases.
  final String? customUrl;

  /// Transient: primary address of the linked device, attached on load.
  final String? deviceAddress;

  /// Null means "未分类"; [DeviceCategory.all] is never stored.
  final DeviceCategory? category;
  final ServiceGlyph? icon;
  final bool isFavorite;
  final int sortOrder;

  /// Manual position inside the home favorites grid, or null when the user
  /// has never reordered the favorites.
  final int? favoriteSortOrder;
  final bool healthCheckEnabled;
  final ServiceStatus? lastStatus;
  final DateTime? lastCheckedAt;

  /// Last time the user opened this service; used for recent-first ordering.
  final DateTime? lastOpenedAt;

  /// Explicitly linked native module, if the user chose one.
  final String? nativeModuleId;

  /// Mode used when the service is opened from any entry point.
  ///
  /// Changing mode inside a viewer is temporary; this value is only changed
  /// from the service settings so opening behaviour stays predictable.
  final ServiceMode defaultMode;

  /// Whether and how saved web credentials are filled automatically.
  final PasswordFillMode passwordFillMode;

  /// Username whose saved password is filled in [PasswordFillMode.auto].
  ///
  /// Null means "use the most recently saved web account".
  final String? defaultCredentialUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasStatus => lastStatus != null;

  bool get isOnline => lastStatus == ServiceStatus.online;

  bool get hasCustomUrl => customUrl != null && customUrl!.trim().isNotEmpty;

  bool get isDeviceLinked => deviceId != null;

  /// The effective URL. Empty when a device-linked service has lost its device
  /// or when neither a device nor a custom URL is available.
  String get url {
    if (hasCustomUrl) {
      return normalizeHttpUrl(customUrl!) ?? customUrl!.trim();
    }
    final String address = deviceAddress?.trim() ?? '';
    if (address.isEmpty) {
      return '';
    }
    return buildServiceUrl(
      address: address,
      protocol: protocol,
      port: port,
      path: path,
    );
  }

  bool get hasUrl => url.isNotEmpty;

  Uri? get uri {
    final String value = url;
    return value.isEmpty ? null : Uri.tryParse(value);
  }

  /// Short address shown in lists, e.g. `192.168.1.10:8080`.
  String get address {
    final Uri? parsed = uri;
    if (parsed == null || parsed.host.isEmpty) {
      return url.isEmpty ? (deviceAddress ?? '未设置地址') : url;
    }
    final String port = parsed.hasPort ? ':${parsed.port}' : '';
    return '${parsed.host}$port';
  }

  String get pathLabel {
    final Uri? parsed = uri;
    if (parsed == null || parsed.path.isEmpty || parsed.path == '/') {
      return '';
    }
    return parsed.path;
  }

  String get categoryLabel => category?.label ?? '未分类';

  String get statusLabel => switch (lastStatus) {
    ServiceStatus.online => '在线',
    ServiceStatus.offline => '离线',
    null => '未检测',
  };

  Service copyWith({
    String? id,
    String? name,
    String? protocol,
    int? Function()? port,
    String? Function()? path,
    String? Function()? customUrl,
    String? Function()? deviceAddress,
    String? Function()? deviceId,
    DeviceCategory? Function()? category,
    ServiceGlyph? Function()? icon,
    bool? isFavorite,
    int? sortOrder,
    int? Function()? favoriteSortOrder,
    bool? healthCheckEnabled,
    ServiceStatus? Function()? lastStatus,
    DateTime? Function()? lastCheckedAt,
    DateTime? Function()? lastOpenedAt,
    String? Function()? nativeModuleId,
    ServiceMode? defaultMode,
    PasswordFillMode? passwordFillMode,
    String? Function()? defaultCredentialUsername,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId == null ? this.deviceId : deviceId(),
      protocol: protocol ?? this.protocol,
      port: port == null ? this.port : port(),
      path: path == null ? this.path : path(),
      customUrl: customUrl == null ? this.customUrl : customUrl(),
      deviceAddress: deviceAddress == null
          ? this.deviceAddress
          : deviceAddress(),
      category: category == null ? this.category : category(),
      icon: icon == null ? this.icon : icon(),
      isFavorite: isFavorite ?? this.isFavorite,
      sortOrder: sortOrder ?? this.sortOrder,
      favoriteSortOrder: favoriteSortOrder == null
          ? this.favoriteSortOrder
          : favoriteSortOrder(),
      healthCheckEnabled: healthCheckEnabled ?? this.healthCheckEnabled,
      lastStatus: lastStatus == null ? this.lastStatus : lastStatus(),
      lastCheckedAt: lastCheckedAt == null
          ? this.lastCheckedAt
          : lastCheckedAt(),
      lastOpenedAt: lastOpenedAt == null ? this.lastOpenedAt : lastOpenedAt(),
      nativeModuleId: nativeModuleId == null
          ? this.nativeModuleId
          : nativeModuleId(),
      defaultMode: defaultMode ?? this.defaultMode,
      passwordFillMode: passwordFillMode ?? this.passwordFillMode,
      defaultCredentialUsername: defaultCredentialUsername == null
          ? this.defaultCredentialUsername
          : defaultCredentialUsername(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'deviceId': deviceId,
      'protocol': protocol,
      'port': port,
      'path': path,
      'customUrl': customUrl,
      'category': category?.name,
      'icon': icon?.name,
      'isFavorite': isFavorite,
      'sortOrder': sortOrder,
      'favoriteSortOrder': favoriteSortOrder,
      'healthCheckEnabled': healthCheckEnabled,
      'lastStatus': lastStatus?.name,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'nativeModuleId': nativeModuleId,
      'defaultMode': defaultMode.name,
      'passwordFillMode': passwordFillMode.name,
      'defaultCredentialUsername': defaultCredentialUsername,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Service.fromMap(Map<String, Object?> map) {
    final String? categoryName = map['category'] as String?;
    final String? iconName = map['icon'] as String?;
    final String? statusName = map['lastStatus'] as String?;
    final String? protocolValue = map['protocol'] as String?;
    final String? customValue =
        map['customUrl'] as String? ??
        (protocolValue == null ? map['url'] as String? : null);
    final int? portValue = (map['port'] as num?)?.toInt();
    return Service(
      id: map['id'] as String,
      name: map['name'] as String,
      deviceId: map['deviceId'] as String?,
      protocol: protocolValue == 'https' ? 'https' : 'http',
      port: portValue,
      path: map['path'] as String?,
      customUrl: customValue,
      category: categoryName == null
          ? null
          : DeviceCategory.values.firstWhere(
              (DeviceCategory value) => value.name == categoryName,
              orElse: () => DeviceCategory.other,
            ),
      icon: iconName == null
          ? null
          : ServiceGlyph.values.firstWhere(
              (ServiceGlyph value) => value.name == iconName,
              orElse: () => ServiceGlyph.generic,
            ),
      isFavorite: map['isFavorite'] as bool? ?? false,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      favoriteSortOrder: (map['favoriteSortOrder'] as num?)?.toInt(),
      healthCheckEnabled: map['healthCheckEnabled'] as bool? ?? false,
      lastStatus: statusName == null
          ? null
          : ServiceStatus.values.firstWhere(
              (ServiceStatus value) => value.name == statusName,
              orElse: () => ServiceStatus.offline,
            ),
      lastCheckedAt: DateTime.tryParse(map['lastCheckedAt'] as String? ?? ''),
      lastOpenedAt: DateTime.tryParse(map['lastOpenedAt'] as String? ?? ''),
      nativeModuleId: map['nativeModuleId'] as String?,
      defaultMode: switch (map['defaultMode'] as String? ??
          map['lastMode'] as String?) {
        'native' => ServiceMode.native,
        _ => ServiceMode.web,
      },
      passwordFillMode: switch (map['passwordFillMode'] as String?) {
        'ask' => PasswordFillMode.ask,
        'off' => PasswordFillMode.off,
        _ => PasswordFillMode.auto,
      },
      defaultCredentialUsername: map['defaultCredentialUsername'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
