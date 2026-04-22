import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';
import '../datasources/device_local_datasource.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceDataSource _dataSource;
  List<Device> _devices = [];

  DeviceRepositoryImpl(this._dataSource);

  @override
  Future<List<Device>> getDevices() async {
    if (_devices.isEmpty) {
      _devices = await _dataSource.getDevices();
    }
    return List.from(_devices);
  }

  @override
  Future<void> addDevice(Device device) async {
    _devices.add(device);
    await _dataSource.saveDevices(_devices);
  }

  @override
  Future<void> updateDevice(Device device) async {
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index != -1) {
      _devices[index] = device;
      await _dataSource.saveDevices(_devices);
    }
  }

  @override
  Future<void> deleteDevice(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await _dataSource.saveDevices(_devices);
  }
}
