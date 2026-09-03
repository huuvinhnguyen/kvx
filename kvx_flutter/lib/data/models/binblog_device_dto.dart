import '../../domain/entities/device.dart';

class BinblogDeviceDto {
  final int id;
  final String name;
  final String? deviceType;
  final int? status;

  const BinblogDeviceDto({
    required this.id,
    required this.name,
    this.deviceType,
    this.status,
  });

  factory BinblogDeviceDto.fromJson(Map<String, dynamic> json) {
    return BinblogDeviceDto(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unnamed device',
      deviceType: json['device_type'] as String?,
      status: json['status'] as int?,
    );
  }

  Device toDomain() {
    final rawType = (deviceType ?? '').toLowerCase();
    final type =
        rawType.contains('dht') ||
            rawType.contains('temperature') ||
            rawType.contains('sensor')
        ? DeviceType.temperature
        : rawType.contains('switch')
        ? DeviceType.switchDevice
        : rawType.contains('ipad')
        ? DeviceType.iPad
        : rawType.contains('simulator')
        ? DeviceType.simulator
        : DeviceType.iPhone;

    final deviceStatus = switch (status) {
      1 => DeviceStatus.online,
      2 => DeviceStatus.busy,
      _ => DeviceStatus.offline,
    };

    return Device(id: '$id', name: name, type: type, status: deviceStatus);
  }
}
