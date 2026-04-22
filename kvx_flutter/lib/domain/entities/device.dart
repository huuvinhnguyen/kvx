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
  final DeviceStatus status;

  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
