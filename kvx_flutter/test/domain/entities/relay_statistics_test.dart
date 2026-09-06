import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/domain/entities/relay_statistics.dart';

void main() {
  group('RelayStatistics', () {
    test('creates instance with required fields', () {
      const statistics = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(hours: 2, minutes: 30),
        activationCount: 15,
      );

      expect(statistics.deviceId, 'device-1');
      expect(statistics.relayIndex, 0);
      expect(statistics.totalOnTime, const Duration(hours: 2, minutes: 30));
      expect(statistics.activationCount, 15);
      expect(statistics.lastActivated, null);
    });

    test('creates instance with optional lastActivated', () {
      final lastActivated = DateTime(2026, 9, 6, 10, 0);
      final statistics = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 1,
        totalOnTime: const Duration(minutes: 45),
        activationCount: 8,
        lastActivated: lastActivated,
      );

      expect(statistics.lastActivated, lastActivated);
    });

    test('copyWith creates new instance with updated fields', () {
      const original = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      final updated = original.copyWith(
        totalOnTime: const Duration(minutes: 20),
        activationCount: 10,
      );

      expect(updated.deviceId, 'device-1');
      expect(updated.relayIndex, 0);
      expect(updated.totalOnTime, const Duration(minutes: 20));
      expect(updated.activationCount, 10);
      expect(original.activationCount, 5); // original unchanged
    });

    test('copyWith preserves fields when not provided', () {
      final lastActivated = DateTime(2026, 9, 6, 10, 0);
      final original = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 2,
        totalOnTime: const Duration(hours: 1),
        activationCount: 12,
        lastActivated: lastActivated,
      );

      final updated = original.copyWith(activationCount: 15);

      expect(updated.deviceId, 'device-1');
      expect(updated.relayIndex, 2);
      expect(updated.totalOnTime, const Duration(hours: 1));
      expect(updated.activationCount, 15);
      expect(updated.lastActivated, lastActivated);
    });

    test('equality based on deviceId and relayIndex', () {
      const statistics1 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      const statistics2 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(hours: 2),
        activationCount: 20,
      );

      const statistics3 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 1,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      const statistics4 = RelayStatistics(
        deviceId: 'device-2',
        relayIndex: 0,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      expect(statistics1, equals(statistics2)); // same deviceId and relayIndex
      expect(statistics1, isNot(equals(statistics3))); // different relayIndex
      expect(statistics1, isNot(equals(statistics4))); // different deviceId
    });

    test('hashCode based on deviceId and relayIndex', () {
      const statistics1 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      const statistics2 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration(hours: 2),
        activationCount: 20,
      );

      const statistics3 = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 1,
        totalOnTime: Duration(minutes: 10),
        activationCount: 5,
      );

      expect(statistics1.hashCode, equals(statistics2.hashCode));
      expect(statistics1.hashCode, isNot(equals(statistics3.hashCode)));
    });

    test('supports zero activation count', () {
      const statistics = RelayStatistics(
        deviceId: 'device-1',
        relayIndex: 0,
        totalOnTime: Duration.zero,
        activationCount: 0,
      );

      expect(statistics.activationCount, 0);
      expect(statistics.totalOnTime, Duration.zero);
    });
  });
}
