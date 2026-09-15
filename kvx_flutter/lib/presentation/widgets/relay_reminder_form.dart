import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/relay_reminder.dart';
import '../../domain/entities/reminder_repeat_type.dart';

enum DurationUnit { seconds, minutes }

class RelayReminderForm extends StatefulWidget {
  final void Function(RelayReminder reminder) onAdd;
  final String deviceId;
  final int relayIndex;
  final bool enabled;

  const RelayReminderForm({
    super.key,
    required this.onAdd,
    required this.deviceId,
    required this.relayIndex,
    this.enabled = true,
  });

  @override
  State<RelayReminderForm> createState() => _RelayReminderFormState();
}

class _RelayReminderFormState extends State<RelayReminderForm> {
  final _durationController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  DurationUnit _selectedUnit = DurationUnit.minutes;
  ReminderRepeatType _selectedRepeatType = ReminderRepeatType.daily;
  String? _errorText;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _handleAdd() {
    setState(() => _errorText = null);

    final text = _durationController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập thời gian hoạt động!');
      return;
    }

    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _errorText = 'Thời gian phải là số nguyên dương!');
      return;
    }

    final duration = _selectedUnit == DurationUnit.minutes
        ? Duration(minutes: value)
        : Duration(seconds: value);

    final reminder = RelayReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: widget.deviceId,
      relayIndex: widget.relayIndex,
      startTime: _selectedDateTime,
      duration: duration,
      repeatType: _selectedRepeatType,
    );

    widget.onAdd(reminder);
    _durationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DateTime picker
          InkWell(
            onTap: widget.enabled ? _selectDateTime : null,
            child: InputDecorator(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(15),
                suffixIcon: const Icon(Icons.calendar_today),
                enabled: widget.enabled,
              ),
              child: Text(
                _formatDateTime(_selectedDateTime),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Duration input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Nhập thời gian',
                    errorText: _errorText,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<DurationUnit>(
                  initialValue: _selectedUnit,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(15),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DurationUnit.seconds,
                      child: Text('Giây'),
                    ),
                    DropdownMenuItem(
                      value: DurationUnit.minutes,
                      child: Text('Phút'),
                    ),
                  ],
                  onChanged: widget.enabled
                      ? (value) => setState(() => _selectedUnit = value!)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Repeat type dropdown
          DropdownButtonFormField<ReminderRepeatType>(
            initialValue: _selectedRepeatType,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(15),
            ),
            items: ReminderRepeatType.values
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ))
                .toList(),
            onChanged: widget.enabled
                ? (value) => setState(() => _selectedRepeatType = value!)
                : null,
          ),
          const SizedBox(height: 30),

          // Submit button
          ElevatedButton(
            onPressed: widget.enabled ? _handleAdd : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Hẹn giờ'),
          ),
        ],
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
}
