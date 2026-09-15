import 'package:flutter/material.dart';
import '../../domain/entities/relay_reminder.dart';

class RelayReminderList extends StatelessWidget {
  final List<RelayReminder> reminders;
  final bool areRemindersActive;
  final ValueChanged<bool>? onToggleAll;
  final ValueChanged<String>? onDelete;
  final bool enabled;

  const RelayReminderList({
    super.key,
    required this.reminders,
    required this.areRemindersActive,
    this.onToggleAll,
    this.onDelete,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle all
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách Hẹn giờ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: areRemindersActive,
                onChanged: enabled ? onToggleAll : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reminder list or empty state
          if (reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Không có hẹn giờ nào được thiết lập.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ...reminders.map((reminder) => _ReminderItem(
                  reminder: reminder,
                  onDelete: enabled ? () => onDelete?.call(reminder.id) : null,
                )),
        ],
      ),
    );
  }
}

class _ReminderItem extends StatelessWidget {
  final RelayReminder reminder;
  final VoidCallback? onDelete;

  const _ReminderItem({
    required this.reminder,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          _formatDateTime(reminder.startTime),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatDuration(reminder.duration)} • ${reminder.repeatType.displayName}',
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes} phút';
    }
    return '${duration.inSeconds} giây';
  }
}
