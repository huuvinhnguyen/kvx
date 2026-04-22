import '../../domain/entities/device.dart';

enum DeviceFilter { all, online, offline, busy }

extension DeviceFilterExtension on DeviceFilter {
  String get displayName {
    switch (this) {
      case DeviceFilter.all:
        return 'All';
      case DeviceFilter.online:
        return 'Online';
      case DeviceFilter.offline:
        return 'Offline';
      case DeviceFilter.busy:
        return 'Busy';
    }
  }

  bool matches(Device device) {
    switch (this) {
      case DeviceFilter.all:
        return true;
      case DeviceFilter.online:
        return device.status == DeviceStatus.online;
      case DeviceFilter.offline:
        return device.status == DeviceStatus.offline;
      case DeviceFilter.busy:
        return device.status == DeviceStatus.busy;
    }
  }
}
