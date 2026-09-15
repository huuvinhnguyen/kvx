import 'package:flutter/material.dart';
import '../../domain/entities/relay_channel.dart';
import '../../domain/entities/relay_reminder.dart';
import '../../domain/entities/relay_statistics.dart';
import '../../domain/entities/reminder_repeat_type.dart';
import '../widgets/relay/relay_toggle_switch.dart';
import '../widgets/relay/relay_longlast_form.dart';
import '../widgets/relay/relay_reminder_form.dart';
import '../widgets/relay/relay_reminder_list.dart';
import '../widgets/relay/device_info_header.dart';
import '../widgets/relay/device_control_footer.dart';

/// Demo screen to showcase all relay control widgets
class RelayWidgetsDemoScreen extends StatefulWidget {
  const RelayWidgetsDemoScreen({super.key});

  @override
  State<RelayWidgetsDemoScreen> createState() => _RelayWidgetsDemoScreenState();
}

class _RelayWidgetsDemoScreenState extends State<RelayWidgetsDemoScreen> {
  final RelayChannel _channel = const RelayChannel(
    index: 0,
    isOn: false,
    label: 'Kênh 1',
  );

  final List<RelayReminder> _reminders = [
    RelayReminder(
      id: '1',
      deviceId: 'demo_device',
      relayIndex: 0,
      startTime: DateTime.now().add(const Duration(hours: 2)),
      duration: const Duration(minutes: 30),
      repeatType: ReminderRepeatType.daily,
      isActive: true,
    ),
    RelayReminder(
      id: '2',
      deviceId: 'demo_device',
      relayIndex: 0,
      startTime: DateTime.now().add(const Duration(days: 1)),
      duration: const Duration(hours: 1),
      repeatType: ReminderRepeatType.weekly,
      isActive: false,
    ),
  ];

  bool _remindersActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relay Widgets Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Info Header
            DeviceInfoHeader(
              deviceName: 'esp8266_demo',
              lastConnected: DateTime.now().subtract(const Duration(minutes: 5)),
              firmwareVersion: 'v1.0.0',
              appVersion: 'v2.0.0',
              onRefresh: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing device...')),
                );
              },
            ),

            const SizedBox(height: 24),

            // Toggle Switch
            const Text(
              'Toggle Switch',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RelayToggleSwitch(
              channel: _channel,
              onToggle: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Toggle: $value')),
                );
              },
            ),

            const SizedBox(height: 24),

            // Longlast Form
            const Text(
              'Longlast Form',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RelayLonglastForm(
              onActivate: (duration) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Activate for ${duration.inSeconds}s'),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Reminder Form
            const Text(
              'Reminder Form',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RelayReminderForm(
              onSubmit: (startTime, duration, repeatType) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Reminder: $startTime, ${duration.inSeconds}s, $repeatType',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Reminder List
            const Text(
              'Reminder List',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RelayReminderList(
              reminders: _reminders,
              remindersActive: _remindersActive,
              onToggleRemindersActive: (value) {
                setState(() {
                  _remindersActive = value;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reminders active: $value')),
                );
              },
              onToggleReminder: (reminder) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Toggle reminder: ${reminder.id}'),
                  ),
                );
              },
              onDeleteReminder: (reminder) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Delete reminder: ${reminder.id}'),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Device Control Footer
            const Text(
              'Device Control Footer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DeviceControlFooter(
              deviceId: 'esp8266_demo',
              firmwareVersion: 'v1.0.0',
              appVersion: 'v2.0.0',
              onRestart: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restarting device...')),
                );
              },
              onResetWifi: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resetting WiFi...')),
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
