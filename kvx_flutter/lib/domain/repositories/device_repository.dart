import '../entities/device.dart';

abstract class DeviceRepository {
  Future<List<Device>> getDevices();
  Future<void> addDevice(Device device);
  Future<void> updateDevice(Device device);
  Future<void> deleteDevice(String id);
}
