/// Logical buckets a local service can belong to.
///
/// [all] is a synthetic filter used by the home screen category grid and is
/// never assigned to a concrete service.
enum DeviceCategory { all, nas, router, computer, docker, phone, media, other }

extension DeviceCategoryLabels on DeviceCategory {
  String get label => switch (this) {
    DeviceCategory.all => '全部设备',
    DeviceCategory.nas => 'NAS',
    DeviceCategory.router => '路由器',
    DeviceCategory.computer => '电脑',
    DeviceCategory.docker => 'Docker',
    DeviceCategory.phone => '手机',
    DeviceCategory.media => '影音',
    DeviceCategory.other => '其他',
  };
}
