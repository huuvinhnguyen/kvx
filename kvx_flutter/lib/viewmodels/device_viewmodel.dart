import 'package:flutter/foundation.dart';
import '../models/device.dart';

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
}

class DeviceViewModel extends ChangeNotifier {
  List<Device> _devices = Device.sampleDevices;
  bool _isLoading = false;
  String _searchText = '';
  DeviceFilter _selectedFilter = DeviceFilter.all;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String get searchText => _searchText;
  DeviceFilter get selectedFilter => _selectedFilter;

  List<Device> get filteredDevices {
    var result = _devices;

    if (_searchText.isNotEmpty) {
      result = result
          .where((d) => d.name.toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }

    switch (_selectedFilter) {
      case DeviceFilter.all:
        break;
      case DeviceFilter.online:
        result = result.where((d) => d.status == DeviceStatus.online).toList();
        break;
      case DeviceFilter.offline:
        result = result.where((d) => d.status == DeviceStatus.offline).toList();
        break;
      case DeviceFilter.busy:
        result = result.where((d) => d.status == DeviceStatus.busy).toList();
        break;
    }

    return result;
  }

  int get onlineCount => _devices.where((d) => d.status == DeviceStatus.online).length;
  int get offlineCount => _devices.where((d) => d.status == DeviceStatus.offline).length;
  int get busyCount => _devices.where((d) => d.status == DeviceStatus.busy).length;

  void setSearchText(String value) {
    _searchText = value;
    notifyListeners();
  }

  void setFilter(DeviceFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _isLoading = false;
    notifyListeners();
  }

  void deleteDevices(List<Device> devicesToDelete) {
    for (final device in devicesToDelete) {
      _devices.removeWhere((d) => d.id == device.id);
    }
    notifyListeners();
  }

  void addDevice({required String name, required DeviceType type, required DeviceStatus status}) {
    _devices.add(Device(name: name, type: type, status: status));
    notifyListeners();
  }

  void toggleStatus(Device device) {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      final currentStatus = _devices[index].status;
      DeviceStatus newStatus;

      switch (currentStatus) {
        case DeviceStatus.online:
          newStatus = DeviceStatus.offline;
          break;
        case DeviceStatus.offline:
          newStatus = DeviceStatus.online;
          break;
        case DeviceStatus.busy:
          newStatus = DeviceStatus.online;
          break;
      }

      _devices[index] = device.copyWith(status: newStatus);
      notifyListeners();
    }
  }
}
