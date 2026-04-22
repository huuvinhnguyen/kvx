import 'package:flutter/material.dart';

enum DeviceType {
  iPhone('iPhone', Icons.phone_iphone),
  iPad('iPad', Icons.tablet),
  simulator('Simulator', Icons.desktop_windows);

  final String displayName;
  final IconData icon;

  const DeviceType(this.displayName, this.icon);
}

enum DeviceStatus {
  online('Online', Colors.green),
  offline('Offline', Colors.grey),
  busy('Busy', Colors.orange);

  final String displayName;
  final Color color;

  const DeviceStatus(this.displayName, this.color);
}

class Device {
  final String id;
  final String name;
  final DeviceType type;
  DeviceStatus status;

  Device({
    String? id,
    required this.name,
    required this.type,
    required this.status,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Device copyWith({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }

  static List<Device> sampleDevices = [
    Device(name: 'iPhone 16 Pro', type: DeviceType.iPhone, status: DeviceStatus.online),
    Device(name: 'iPhone 15', type: DeviceType.iPhone, status: DeviceStatus.busy),
    Device(name: 'iPhone 14 Pro', type: DeviceType.iPhone, status: DeviceStatus.offline),
    Device(name: 'iPad Pro 13"', type: DeviceType.iPad, status: DeviceStatus.online),
    Device(name: 'iPad Air', type: DeviceType.iPad, status: DeviceStatus.offline),
    Device(name: 'iPhone SE', type: DeviceType.iPhone, status: DeviceStatus.online),
    Device(name: 'Vision Simulator', type: DeviceType.simulator, status: DeviceStatus.online),
  ];
}
