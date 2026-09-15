import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvx_flutter/domain/entities/relay_reminder.dart';
import 'package:kvx_flutter/domain/entities/reminder_repeat_type.dart';
import 'package:kvx_flutter/presentation/widgets/relay_reminder_list.dart';

void main() {
  group('RelayReminderList', () {
    testWidgets('renders header with toggle switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: const [],
              areRemindersActive: false,
              onToggleAll: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Danh sách Hẹn giờ'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('shows empty state when no reminders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: const [],
              areRemindersActive: false,
            ),
          ),
        ),
      );

      expect(find.text('Không có hẹn giờ nào được thiết lập.'), findsOneWidget);
    });

    testWidgets('displays list of reminders', (tester) async {
      final reminders = [
        RelayReminder(
          id: '1',
          deviceId: 'device1',
          relayIndex: 0,
          startTime: DateTime(2026, 9, 6, 10, 0),
          duration: const Duration(minutes: 5),
          repeatType: ReminderRepeatType.daily,
        ),
        RelayReminder(
          id: '2',
          deviceId: 'device1',
          relayIndex: 0,
          startTime: DateTime(2026, 9, 7, 14, 30),
          duration: const Duration(seconds: 30),
          repeatType: ReminderRepeatType.weekly,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: reminders,
              areRemindersActive: true,
            ),
          ),
        ),
      );

      expect(find.text('06/09/2026 10:00'), findsOneWidget);
      expect(find.text('5 phút • Hằng ngày'), findsOneWidget);
      expect(find.text('07/09/2026 14:30'), findsOneWidget);
      expect(find.text('30 giây • Hằng tuần'), findsOneWidget);
    });

    testWidgets('calls onToggleAll when switch is toggled', (tester) async {
      bool? toggledValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: const [],
              areRemindersActive: false,
              onToggleAll: (value) => toggledValue = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(toggledValue, isTrue);
    });

    testWidgets('calls onDelete when delete button is tapped', (tester) async {
      String? deletedId;
      final reminder = RelayReminder(
        id: 'test-id',
        deviceId: 'device1',
        relayIndex: 0,
        startTime: DateTime(2026, 9, 6, 10, 0),
        duration: const Duration(minutes: 5),
        repeatType: ReminderRepeatType.daily,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: [reminder],
              areRemindersActive: true,
              onDelete: (id) => deletedId = id,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(deletedId, 'test-id');
    });

    testWidgets('does not show delete button when disabled', (tester) async {
      final reminder = RelayReminder(
        id: 'test-id',
        deviceId: 'device1',
        relayIndex: 0,
        startTime: DateTime(2026, 9, 6, 10, 0),
        duration: const Duration(minutes: 5),
        repeatType: ReminderRepeatType.daily,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayReminderList(
              reminders: [reminder],
              areRemindersActive: true,
              enabled: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete), findsNothing);
    });
  });
}
