enum DeviceType { iPhone, iPad, simulator, switchDevice, temperature }

enum DeviceStatus { online, offline, busy }

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
