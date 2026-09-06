class RelayStatistics {
  final String deviceId;
  final int relayIndex;
  final Duration totalOnTime;
  final int activationCount;
  final DateTime? lastActivated;

  const RelayStatistics({
    required this.deviceId,
    required this.relayIndex,
    required this.totalOnTime,
    required this.activationCount,
    this.lastActivated,
  });

  RelayStatistics copyWith({
    String? deviceId,
    int? relayIndex,
    Duration? totalOnTime,
    int? activationCount,
    DateTime? lastActivated,
  }) {
    return RelayStatistics(
      deviceId: deviceId ?? this.deviceId,
      relayIndex: relayIndex ?? this.relayIndex,
      totalOnTime: totalOnTime ?? this.totalOnTime,
      activationCount: activationCount ?? this.activationCount,
      lastActivated: lastActivated ?? this.lastActivated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayStatistics &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          relayIndex == other.relayIndex;

  @override
  int get hashCode => Object.hash(deviceId, relayIndex);
}
