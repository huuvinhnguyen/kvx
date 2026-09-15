import 'relay_channel.dart';

enum DeviceType { iPhone, iPad, simulator, switchDevice, temperature, pir }

enum DeviceStatus { online, offline, busy }

class Device {
  final String id;
  final String name;
  final String? chipId;
  final DeviceType type;
  final DeviceStatus status;

  // Relay-specific fields (null for non-relay devices)
  final int? relayCount;
  final List<RelayChannel>? relayChannels;
  final String? firmwareVersion;
  final String? appVersion;
  final DateTime? lastConnected;

  const Device({
    required this.id,
    required this.name,
    this.chipId,
    required this.type,
    required this.status,
    this.relayCount,
    this.relayChannels,
    this.firmwareVersion,
    this.appVersion,
    this.lastConnected,
  });

  Device copyWith({
    String? id,
    String? name,
    String? chipId,
    DeviceType? type,
    DeviceStatus? status,
    int? relayCount,
    List<RelayChannel>? relayChannels,
    String? firmwareVersion,
    String? appVersion,
    DateTime? lastConnected,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      chipId: chipId ?? this.chipId,
      type: type ?? this.type,
      status: status ?? this.status,
      relayCount: relayCount ?? this.relayCount,
      relayChannels: relayChannels ?? this.relayChannels,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      appVersion: appVersion ?? this.appVersion,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
