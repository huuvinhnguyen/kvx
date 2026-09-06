import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/domain/entities/relay_reminder.dart';
import 'package:kvx_flutter/domain/entities/reminder_repeat_type.dart';

void main() {
  group('RelayReminder', () {
    final now = DateTime(2026, 9, 6, 10, 0);
    final duration = const Duration(minutes: 5);

    test('creates instance with required fields', () {
      final reminder = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
      );

      expect(reminder.id, 'reminder-1');
      expect(reminder.deviceId, 'device-1');
      expect(reminder.relayIndex, 0);
      expect(reminder.duration, duration);
      expect(reminder.repeatType, ReminderRepeatType.daily);
      expect(reminder.isActive, true); // default
    });

    test('creates instance with custom isActive', () {
      final reminder = RelayReminder(
        id: 'reminder-2',
        deviceId: 'device-1',
        relayIndex: 1,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.weekly,
        isActive: false,
      );

      expect(reminder.isActive, false);
    });

    test('validates relayIndex >= 0', () {
      expect(
        () => RelayReminder(
          id: 'reminder-1',
          deviceId: 'device-1',
          relayIndex: -1,
          startTime: now,
          duration: duration,
          repeatType: ReminderRepeatType.none,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith creates new instance with updated fields', () {
      final original = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
        isActive: true,
      );

      final updated = original.copyWith(
        isActive: false,
        repeatType: ReminderRepeatType.weekly,
      );

      expect(updated.id, 'reminder-1');
      expect(updated.isActive, false);
      expect(updated.repeatType, ReminderRepeatType.weekly);
      expect(original.isActive, true); // original unchanged
    });

    test('copyWith validates duration is positive', () {
      final original = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
      );

      expect(
        () => original.copyWith(duration: Duration.zero),
        throwsArgumentError,
      );

      expect(
        () => original.copyWith(duration: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('equality based on id', () {
      final reminder1 = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
      );

      final reminder2 = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-2',
        relayIndex: 1,
        startTime: now,
        duration: const Duration(minutes: 10),
        repeatType: ReminderRepeatType.weekly,
      );

      final reminder3 = RelayReminder(
        id: 'reminder-2',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
      );

      expect(reminder1, equals(reminder2)); // same id
      expect(reminder1, isNot(equals(reminder3))); // different id
    });

    test('hashCode based on id', () {
      final reminder1 = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-1',
        relayIndex: 0,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.daily,
      );

      final reminder2 = RelayReminder(
        id: 'reminder-1',
        deviceId: 'device-2',
        relayIndex: 1,
        startTime: now,
        duration: duration,
        repeatType: ReminderRepeatType.weekly,
      );

      expect(reminder1.hashCode, equals(reminder2.hashCode));
    });
  });

  group('ReminderRepeatType', () {
    test('has Vietnamese display names', () {
      expect(ReminderRepeatType.none.displayName, 'Không lặp lại');
      expect(ReminderRepeatType.daily.displayName, 'Hằng ngày');
      expect(ReminderRepeatType.weekly.displayName, 'Hằng tuần');
      expect(ReminderRepeatType.monthly.displayName, 'Hằng tháng');
    });

    test('enum values match expected cases', () {
      expect(ReminderRepeatType.values.length, 4);
      expect(ReminderRepeatType.values, contains(ReminderRepeatType.none));
      expect(ReminderRepeatType.values, contains(ReminderRepeatType.daily));
      expect(ReminderRepeatType.values, contains(ReminderRepeatType.weekly));
      expect(ReminderRepeatType.values, contains(ReminderRepeatType.monthly));
    });
  });
}
