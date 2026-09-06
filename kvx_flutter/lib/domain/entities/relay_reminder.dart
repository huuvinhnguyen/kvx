import 'reminder_repeat_type.dart';

class RelayReminder {
  final String id;
  final String deviceId;
  final int relayIndex;
  final DateTime startTime;
  final Duration duration;
  final ReminderRepeatType repeatType;
  final bool isActive;

  const RelayReminder({
    required this.id,
    required this.deviceId,
    required this.relayIndex,
    required this.startTime,
    required this.duration,
    required this.repeatType,
    this.isActive = true,
  }) : assert(relayIndex >= 0, 'relayIndex must be >= 0');

  RelayReminder copyWith({
    String? id,
    String? deviceId,
    int? relayIndex,
    DateTime? startTime,
    Duration? duration,
    ReminderRepeatType? repeatType,
    bool? isActive,
  }) {
    if (duration != null && duration <= Duration.zero) {
      throw ArgumentError('Duration must be positive');
    }

    return RelayReminder(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      relayIndex: relayIndex ?? this.relayIndex,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      repeatType: repeatType ?? this.repeatType,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayReminder &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
