import 'package:flutter/material.dart';

enum ScheduleType {
  daily('Hằng ngày'),
  weekly('Hằng tuần'),
  once('Một lần');

  final String displayName;
  const ScheduleType(this.displayName);
}

class Schedule {
  final String id;
  final String deviceId;
  final DateTime time;
  final ScheduleType type;
  final bool isActive;

  const Schedule({
    required this.id,
    required this.deviceId,
    required this.time,
    required this.type,
    this.isActive = true,
  });

  Schedule copyWith({
    String? id,
    String? deviceId,
    DateTime? time,
    ScheduleType? type,
    bool? isActive,
  }) {
    return Schedule(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      time: time ?? this.time,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Schedule && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
