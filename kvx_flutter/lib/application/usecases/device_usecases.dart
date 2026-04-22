import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';

class GetDevicesUseCase {
  final DeviceRepository _repository;

  GetDevicesUseCase(this._repository);

  Future<List<Device>> call() => _repository.getDevices();
}

class AddDeviceUseCase {
  final DeviceRepository _repository;

  AddDeviceUseCase(this._repository);

  Future<void> call(Device device) => _repository.addDevice(device);
}

class UpdateDeviceUseCase {
  final DeviceRepository _repository;

  UpdateDeviceUseCase(this._repository);

  Future<void> call(Device device) => _repository.updateDevice(device);
}

class DeleteDeviceUseCase {
  final DeviceRepository _repository;

  DeleteDeviceUseCase(this._repository);

  Future<void> call(String id) => _repository.deleteDevice(id);
}

class ToggleDeviceStatusUseCase {
  final DeviceRepository _repository;

  ToggleDeviceStatusUseCase(this._repository);

  Future<Device?> call(Device device) async {
    DeviceStatus newStatus;
    switch (device.status) {
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

    final updatedDevice = device.copyWith(status: newStatus);
    await _repository.updateDevice(updatedDevice);
    return updatedDevice;
  }
}
