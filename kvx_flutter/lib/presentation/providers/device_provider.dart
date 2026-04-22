import 'package:flutter/foundation.dart';
import '../../application/usecases/device_usecases.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/device_filter.dart';

class DeviceProvider extends ChangeNotifier {
  final GetDevicesUseCase _getDevicesUseCase;
  final AddDeviceUseCase _addDeviceUseCase;
  final DeleteDeviceUseCase _deleteDeviceUseCase;
  final ToggleDeviceStatusUseCase _toggleStatusUseCase;

  DeviceProvider({
    required GetDevicesUseCase getDevicesUseCase,
    required AddDeviceUseCase addDeviceUseCase,
    required DeleteDeviceUseCase deleteDeviceUseCase,
    required ToggleDeviceStatusUseCase toggleStatusUseCase,
  })  : _getDevicesUseCase = getDevicesUseCase,
        _addDeviceUseCase = addDeviceUseCase,
        _deleteDeviceUseCase = deleteDeviceUseCase,
        _toggleStatusUseCase = toggleStatusUseCase;

  List<Device> _devices = [];
  bool _isLoading = false;
  String _searchText = '';
  DeviceFilter _selectedFilter = DeviceFilter.all;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String get searchText => _searchText;
  DeviceFilter get selectedFilter => _selectedFilter;

  List<Device> get filteredDevices {
    var result = _devices.where((d) => d.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
    return result.where((d) => _selectedFilter.matches(d)).toList();
  }

  int get onlineCount => _devices.where((d) => d.status == DeviceStatus.online).length;
  int get offlineCount => _devices.where((d) => d.status == DeviceStatus.offline).length;
  int get busyCount => _devices.where((d) => d.status == DeviceStatus.busy).length;

  Future<void> loadDevices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _devices = await _getDevicesUseCase();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadDevices();
  }

  void setSearchText(String value) {
    _searchText = value;
    notifyListeners();
  }

  void setFilter(DeviceFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> addDevice({required String name, required DeviceType type, required DeviceStatus status}) async {
    final device = Device(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      status: status,
    );
    await _addDeviceUseCase(device);
    _devices.add(device);
    notifyListeners();
  }

  Future<void> deleteDevice(Device device) async {
    await _deleteDeviceUseCase(device.id);
    _devices.removeWhere((d) => d.id == device.id);
    notifyListeners();
  }

  Future<void> toggleStatus(Device device) async {
    final updatedDevice = await _toggleStatusUseCase(device);
    if (updatedDevice != null) {
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        _devices[index] = updatedDevice;
        notifyListeners();
      }
    }
  }
}
