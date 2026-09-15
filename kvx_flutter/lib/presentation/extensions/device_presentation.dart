import 'package:flutter/material.dart';

import '../../domain/entities/device.dart';

extension DeviceTypePresentation on DeviceType {
  String get displayName => switch (this) {
    DeviceType.pir => 'PIR',
    DeviceType.iPhone => 'iPhone',
    DeviceType.iPad => 'iPad',
    DeviceType.simulator => 'Simulator',
    DeviceType.switchDevice => 'Switch',
    DeviceType.temperature => 'Temperature',
  };

  IconData get icon => switch (this) {
    DeviceType.pir => Icons.sensors,
    DeviceType.iPhone => Icons.phone_iphone,
    DeviceType.iPad => Icons.tablet,
    DeviceType.simulator => Icons.desktop_windows,
    DeviceType.switchDevice => Icons.power,
    DeviceType.temperature => Icons.thermostat,
  };
}

extension DeviceStatusPresentation on DeviceStatus {
  String get displayName => switch (this) {
    DeviceStatus.online => 'Online',
    DeviceStatus.offline => 'Offline',
    DeviceStatus.busy => 'Busy',
  };

  Color get color => switch (this) {
    DeviceStatus.online => Colors.green,
    DeviceStatus.offline => Colors.grey,
    DeviceStatus.busy => Colors.orange,
  };
}
