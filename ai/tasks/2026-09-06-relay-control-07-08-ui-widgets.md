# Task 07-08 — Relay Control UI Widgets

## Status

Ready to start (depends on Task 01).

## Goal

Create reusable, tested UI widgets for relay control. These widgets are presentation components that accept callbacks and display data, with no business logic.

## Scope

- Flutter presentation layer only.
- Create 7 shared widgets (toggle, forms, lists, headers, footers).
- Keep widgets dumb: accept data via props, emit events via callbacks.
- Support accessibility, light/dark mode.
- Write widget tests for user interactions.

## Prerequisites

- Task 01 complete: domain entities exist for type signatures
- Understanding of existing widget patterns
- Material Design 3 familiarity

## Architecture Decision

**Widget Composition Strategy:**
- Small, focused widgets with single responsibility
- Props-down, events-up pattern (React-style)
- No direct use case calls (provider handles that)
- Reusable across different relay devices

**Why separate widgets:**
- Easier to test in isolation
- Reusable across screens
- Clear boundaries of responsibility
- Easier to maintain and modify

## Relevant Existing Files

- `kvx_flutter/lib/presentation/widgets/device_row.dart` (pattern reference)
- `kvx_flutter/lib/presentation/widgets/filter_bar.dart`
- `kvx_flutter/lib/domain/entities/relay_reminder.dart`
- `kvx_flutter/lib/presentation/extensions/device_presentation.dart`

## Expected Files

**Create:**
- `kvx_flutter/lib/presentation/widgets/relay_toggle_switch.dart`
- `kvx_flutter/lib/presentation/widgets/relay_longlast_form.dart`
- `kvx_flutter/lib/presentation/widgets/relay_reminder_form.dart`
- `kvx_flutter/lib/presentation/widgets/relay_reminder_list.dart`
- `kvx_flutter/lib/presentation/widgets/device_info_header.dart`
- `kvx_flutter/lib/presentation/widgets/device_control_footer.dart`
- `kvx_flutter/lib/presentation/widgets/confirmation_dialog.dart`
- `kvx_flutter/lib/presentation/extensions/duration_extensions.dart`

**Test:**
- `kvx_flutter/test/presentation/widgets/relay_toggle_switch_test.dart`
- `kvx_flutter/test/presentation/widgets/relay_longlast_form_test.dart`
- `kvx_flutter/test/presentation/widgets/relay_reminder_form_test.dart`
- `kvx_flutter/test/presentation/widgets/relay_reminder_list_test.dart`

---

## Widget 1: RelayToggleSwitch

### Purpose
Large, prominent switch for turning relay on/off.

### Implementation

```dart
import 'package:flutter/material.dart';

class RelayToggleSwitch extends StatelessWidget {
  final bool isOn;
  final bool isLoading;
  final ValueChanged<bool>? onChanged;

  const RelayToggleSwitch({
    super.key,
    required this.isOn,
    this.isLoading = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 80,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Transform.scale(
              scale: 2.0,
              child: Switch(
                value: isOn,
                onChanged: onChanged,
                activeColor: Colors.green,
              ),
            ),
          const SizedBox(width: 20),
          Text(
            isOn ? 'BẬT' : 'TẮT',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isOn ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
```

### Widget Test

```dart
void main() {
  testWidgets('displays ON state correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayToggleSwitch(isOn: true, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('BẬT'), findsOneWidget);
    expect(find.text('TẮT'), findsNothing);
  });

  testWidgets('calls onChanged when tapped', (tester) async {
    bool? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayToggleSwitch(
            isOn: false,
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(changedValue, true);
  });

  testWidgets('shows loading indicator when isLoading is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayToggleSwitch(isOn: false, isLoading: true),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
}
```

---

## Widget 2: RelayLonglastForm

### Purpose
Form to activate relay for a specific duration.

### Implementation

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DurationUnit {
  seconds('Giây'),
  minutes('Phút');

  final String displayName;
  const DurationUnit(this.displayName);
}

class RelayLonglastForm extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<Duration> onActivate;

  const RelayLonglastForm({
    super.key,
    this.isLoading = false,
    required this.onActivate,
  });

  @override
  State<RelayLonglastForm> createState() => _RelayLonglastFormState();
}

class _RelayLonglastFormState extends State<RelayLonglastForm> {
  final _controller = TextEditingController();
  DurationUnit _selectedUnit = DurationUnit.seconds;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    setState(() {
      _errorText = null;
    });

    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorText = 'Vui lòng nhập thời gian';
      });
      return;
    }

    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      setState(() {
        _errorText = 'Thời gian phải là số nguyên dương';
      });
      return;
    }

    final duration = _selectedUnit == DurationUnit.minutes
        ? Duration(minutes: value)
        : Duration(seconds: value);

    widget.onActivate(duration);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !widget.isLoading,
            decoration: InputDecoration(
              labelText: 'Nhập thời gian',
              errorText: _errorText,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(15),
            ),
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<DurationUnit>(
            value: _selectedUnit,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(15),
            ),
            style: const TextStyle(fontSize: 24),
            items: DurationUnit.values.map((unit) {
              return DropdownMenuItem(
                value: unit,
                child: Center(child: Text(unit.displayName)),
              );
            }).toList(),
            onChanged: widget.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedUnit = value;
                      });
                    }
                  },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'KÍCH HOẠT',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Widget Test

```dart
void main() {
  testWidgets('validates positive integer input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayLonglastForm(onActivate: (_) {}),
        ),
      ),
    );

    // Try to submit empty
    await tester.tap(find.text('KÍCH HOẠT'));
    await tester.pump();
    expect(find.text('Vui lòng nhập thời gian'), findsOneWidget);

    // Try to submit zero
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('KÍCH HOẠT'));
    await tester.pump();
    expect(find.text('Thời gian phải là số nguyên dương'), findsOneWidget);
  });

  testWidgets('calls onActivate with correct duration', (tester) async {
    Duration? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayLonglastForm(
            onActivate: (duration) => result = duration,
          ),
        ),
      ),
    );

    // Enter 5 seconds
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('KÍCH HOẠT'));

    expect(result, const Duration(seconds: 5));
  });

  testWidgets('converts minutes to duration correctly', (tester) async {
    Duration? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayLonglastForm(
            onActivate: (duration) => result = duration,
          ),
        ),
      ),
    );

    // Select minutes
    await tester.tap(find.byType(DropdownButtonFormField<DurationUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phút').last);
    await tester.pumpAndSettle();

    // Enter 3 minutes
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('KÍCH HOẠT'));

    expect(result, const Duration(minutes: 3));
  });
}
```

---

## Widget 3: RelayReminderForm

### Purpose
Form to schedule relay activation with repeat patterns.

### Implementation

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/reminder_repeat_type.dart';

class RelayReminderForm extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<ReminderFormData> onAdd;

  const RelayReminderForm({
    super.key,
    this.isLoading = false,
    required this.onAdd,
  });

  @override
  State<RelayReminderForm> createState() => _RelayReminderFormState();
}

class _RelayReminderFormState extends State<RelayReminderForm> {
  DateTime _selectedDateTime = DateTime.now();
  final _durationController = TextEditingController();
  DurationUnit _durationUnit = DurationUnit.minutes;
  ReminderRepeatType _repeatType = ReminderRepeatType.daily;

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

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (time == null) return;

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

  void _onSubmit() {
    final text = _durationController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập thời gian hoạt động')),
      );
      return;
    }

    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời gian phải là số nguyên dương'),
        ),
      );
      return;
    }

    final duration = _durationUnit == DurationUnit.minutes
        ? Duration(minutes: value)
        : Duration(seconds: value);

    widget.onAdd(ReminderFormData(
      startTime: _selectedDateTime,
      duration: duration,
      repeatType: _repeatType,
    ));

    _durationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DateTime picker
          InkWell(
            onTap: widget.isLoading ? null : _selectDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Thời gian bắt đầu',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !widget.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian hoạt động',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<DurationUnit>(
                  value: _durationUnit,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 18),
                  items: DurationUnit.values.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit.displayName),
                    );
                  }).toList(),
                  onChanged: widget.isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _durationUnit = value;
                            });
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Repeat type
          DropdownButtonFormField<ReminderRepeatType>(
            value: _repeatType,
            decoration: const InputDecoration(
              labelText: 'Loại lặp lại',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 18),
            items: ReminderRepeatType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: widget.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _repeatType = value;
                      });
                    }
                  },
          ),
          const SizedBox(height: 30),
          
          // Submit button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : _onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hẹn giờ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
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

class ReminderFormData {
  final DateTime startTime;
  final Duration duration;
  final ReminderRepeatType repeatType;

  const ReminderFormData({
    required this.startTime,
    required this.duration,
    required this.repeatType,
  });
}
```

---

## Widget 4: RelayReminderList

### Purpose
Display list of reminders with toggle all and delete actions.

### Implementation

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/relay_reminder.dart';
import '../extensions/duration_extensions.dart';

class RelayReminderList extends StatelessWidget {
  final List<RelayReminder> reminders;
  final bool areRemindersActive;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<String> onDelete;

  const RelayReminderList({
    super.key,
    required this.reminders,
    required this.areRemindersActive,
    required this.onToggleAll,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách Hẹn giờ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Transform.scale(
                scale: 1.5,
                child: Switch(
                  value: areRemindersActive,
                  onChanged: onToggleAll,
                  activeColor: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Không có hẹn giờ nào được thiết lập.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reminders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                return _ReminderItem(
                  reminder: reminder,
                  onDelete: () => onDelete(reminder.id),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReminderItem extends StatelessWidget {
  final RelayReminder reminder;
  final VoidCallback onDelete;

  const _ReminderItem({
    required this.reminder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 20,
            color: reminder.isActive ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(reminder.startTime),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: reminder.isActive ? Colors.black : Colors.grey,
                  ),
                ),
                Text(
                  '${reminder.duration.toVietnamese()} • ${reminder.repeatType.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')} '
        '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
```

---

## Extension: DurationExtensions

```dart
// duration_extensions.dart

extension DurationExtensions on Duration {
  String toVietnamese() {
    if (inMinutes > 0) {
      final hours = inHours;
      final minutes = inMinutes % 60;
      
      if (hours > 0) {
        if (minutes > 0) {
          return '$hours giờ $minutes phút';
        }
        return '$hours giờ';
      }
      return '$minutes phút';
    }
    
    return '$inSeconds giây';
  }
}
```

---

## Widget 5: DeviceInfoHeader

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/device.dart';
import '../extensions/device_presentation.dart';

class DeviceInfoHeader extends StatelessWidget {
  final Device device;

  const DeviceInfoHeader({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: device.status.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  device.type.icon,
                  size: 28,
                  color: device.status.color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: device.status),
            ],
          ),
          if (device.lastConnected != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Lần kết nối cuối: ${_formatDateTime(device.lastConnected!)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          if (device.firmwareVersion != null || device.appVersion != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (device.firmwareVersion != null)
                  Text(
                    '🛠️ v${device.firmwareVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (device.firmwareVersion != null && device.appVersion != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('|', style: TextStyle(color: Colors.grey.shade400)),
                  ),
                if (device.appVersion != null)
                  Text(
                    '📱 v${device.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
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

class _StatusBadge extends StatelessWidget {
  final DeviceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Widget 6: DeviceControlFooter

```dart
import 'package:flutter/material.dart';
import 'confirmation_dialog.dart';

class DeviceControlFooter extends StatelessWidget {
  final String deviceId;
  final String? firmwareVersion;
  final String? appVersion;
  final VoidCallback onRefresh;
  final VoidCallback onRestart;
  final VoidCallback onResetWifi;

  const DeviceControlFooter({
    super.key,
    required this.deviceId,
    this.firmwareVersion,
    this.appVersion,
    required this.onRefresh,
    required this.onRestart,
    required this.onResetWifi,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Device info
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                '🆔 $deviceId',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (firmwareVersion != null || appVersion != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (firmwareVersion != null)
                      Text(
                        '🛠️ v$firmwareVersion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (firmwareVersion != null && appVersion != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|', style: TextStyle(color: Colors.grey.shade400)),
                      ),
                    if (appVersion != null)
                      Text(
                        '📱 v$appVersion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Refresh button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('🔄 Làm mới'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Restart button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showRestartConfirmation(context),
              icon: const Icon(Icons.restart_alt),
              label: const Text('🔁 Khởi động lại thiết bị'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Reset WiFi button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showResetWifiConfirmation(context),
              icon: const Icon(Icons.wifi_off),
              label: const Text('📶 Thay đổi WiFi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showRestartConfirmation(BuildContext context) {
    showConfirmationDialog(
      context: context,
      title: 'Khởi động lại thiết bị',
      message: 'Bạn có chắc muốn khởi động lại thiết bị không?',
      confirmText: 'Khởi động lại',
      cancelText: 'Hủy',
      isDangerous: true,
      onConfirm: onRestart,
    );
  }

  void _showResetWifiConfirmation(BuildContext context) {
    showConfirmationDialog(
      context: context,
      title: 'Thay đổi WiFi',
      message:
          'Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?',
      confirmText: 'Thay đổi',
      cancelText: 'Hủy',
      isDangerous: true,
      onConfirm: onResetWifi,
    );
  }
}
```

---

## Widget 7: ConfirmationDialog

```dart
// confirmation_dialog.dart

import 'package:flutter/material.dart';

Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Xác nhận',
  String cancelText = 'Hủy',
  bool isDangerous = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : null,
              foregroundColor: isDangerous ? Colors.white : null,
            ),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}
```

---

## Acceptance Criteria

- [ ] All 7 widgets compile without errors
- [ ] Widgets accept props and emit callbacks (no direct use case calls)
- [ ] Loading states supported (disabled controls, spinners)
- [ ] Validation works (duration > 0, required fields)
- [ ] Error messages in Vietnamese
- [ ] Light/dark mode supported (use Theme colors)
- [ ] Accessibility: semantic labels, sufficient contrast
- [ ] Widget tests cover:
  - Rendering with various props
  - User interactions (tap, input, select)
  - Validation errors
  - Callbacks fired correctly

## Verification

```bash
cd kvx_flutter
flutter test test/presentation/widgets/
```

Expected: All widget tests pass.

## Implementation Notes

### Props-Down, Events-Up Pattern

```dart
// ✅ Good: Widget accepts data and callbacks
RelayToggleSwitch(
  isOn: state.relayIsOn,
  isLoading: state.isLoading,
  onChanged: (value) => provider.toggleRelay(value),
)

// ❌ Bad: Widget calls provider directly
RelayToggleSwitch() // has Provider.of() inside
```

### Form Validation

- Validate on submit, not on every keystroke
- Show error text below field
- Clear error when user starts typing again

### Accessibility

- Use `Semantics` widget for screen readers
- Provide labels for icon-only buttons
- Ensure sufficient color contrast (WCAG AA)

## Risks / Limitations

- **Risk**: Complex form state management
  - **Mitigation**: Use StatefulWidget, dispose controllers properly

- **Risk**: Date/time picker UI inconsistency across platforms
  - **Mitigation**: Use Material date/time pickers (consistent look)

- **Limitation**: No custom validation rules (e.g., max duration)
  - **Rationale**: Keep widgets simple, add later if needed

## Out of Scope

- Real-time relay state updates (provider handles polling)
- Undo/redo for reminder changes
- Drag-to-reorder reminders
- Custom duration picker (use text input + dropdown)

## Follow-Up Tasks

After completion:
- Task 09: Provider integrates these widgets
- Task 10: Compose widgets into screens
- Task 15: Accessibility audit and polish
