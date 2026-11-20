/// Physical / logical device types supported by LANDeck.
enum DeviceType { nas, router, computer, docker, phone, media, other }

extension DeviceTypeLabels on DeviceType {
  String get label => switch (this) {
    DeviceType.nas => 'NAS',
    DeviceType.router => '路由器',
    DeviceType.computer => '电脑',
    DeviceType.docker => 'Docker',
    DeviceType.phone => '手机',
    DeviceType.media => '影音',
    DeviceType.other => '其他',
  };
}

/// A real device record persisted on the phone.
///
/// Services point at a device by id and derive their URL from
/// [primaryAddress]. Deleting a device keeps its services alive by freezing
/// their current URLs and clearing their assignment instead of cascading.
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.primaryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.icon,
    this.notes,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final DeviceType deviceType;

  /// IPv4, hostname or domain (no scheme, port or path).
  final String primaryAddress;
  final String? icon;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAddress => primaryAddress.trim().isNotEmpty;

  String get addressLabel =>
      hasAddress ? primaryAddress.trim() : '未填写地址';

  Device copyWith({
    String? id,
    String? name,
    DeviceType? deviceType,
    String? primaryAddress,
    String? Function()? icon,
    String? Function()? notes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      primaryAddress: primaryAddress ?? this.primaryAddress,
      icon: icon == null ? this.icon : icon(),
      notes: notes == null ? this.notes : notes(),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'deviceType': deviceType.name,
      'primaryAddress': primaryAddress,
      'icon': icon,
      'notes': notes,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Device.fromMap(Map<String, Object?> map) {
    final String typeName = map['deviceType'] as String? ?? 'other';
    final String primary = (map['primaryAddress'] as String?)?.trim() ??
        (map['ipAddress'] as String?)?.trim() ??
        (map['hostname'] as String?)?.trim() ??
        '';
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      deviceType: DeviceType.values.firstWhere(
        (DeviceType value) => value.name == typeName,
        orElse: () => DeviceType.other,
      ),
      primaryAddress: primary,
      icon: map['icon'] as String?,
      notes: map['notes'] as String?,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
