import '../../domain/entities/device.dart';

abstract class DeviceDataSource {
  Future<List<Device>> getDevices();
  Future<void> saveDevices(List<Device> devices);
}
