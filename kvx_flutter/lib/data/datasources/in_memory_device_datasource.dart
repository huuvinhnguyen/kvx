import '../../domain/entities/device.dart';
import 'device_local_datasource.dart';

class InMemoryDeviceDataSource implements DeviceDataSource {
  final List<Device> _devices = [
    Device(id: '1', name: 'iPhone 16 Pro', type: DeviceType.iPhone, status: DeviceStatus.online),
    Device(id: '2', name: 'iPhone 15', type: DeviceType.iPhone, status: DeviceStatus.busy),
    Device(id: '3', name: 'iPhone 14 Pro', type: DeviceType.iPhone, status: DeviceStatus.offline),
    Device(id: '4', name: 'iPad Pro 13"', type: DeviceType.iPad, status: DeviceStatus.online),
    Device(id: '5', name: 'iPad Air', type: DeviceType.iPad, status: DeviceStatus.offline),
    Device(id: '6', name: 'iPhone SE', type: DeviceType.iPhone, status: DeviceStatus.online),
    Device(id: '7', name: 'Vision Simulator', type: DeviceType.simulator, status: DeviceStatus.online),
  ];

  @override
  Future<List<Device>> getDevices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_devices);
  }

  @override
  Future<void> saveDevices(List<Device> devices) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _devices.clear();
    _devices.addAll(devices);
  }
}
