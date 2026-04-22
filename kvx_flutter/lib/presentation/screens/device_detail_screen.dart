import 'package:flutter/material.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/schedule.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool _isOn = false;
  TimeOfDay _selectedTime = TimeOfDay.now();
  ScheduleType _selectedScheduleType = ScheduleType.daily;
  final List<Schedule> _schedules = [];
  final _timeInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateTimeInput();
  }

  void _updateTimeInput() {
    _timeInputController.text =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timeInputController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _updateTimeInput();
      });
    }
  }

  void _addSchedule() {
    final now = DateTime.now();
    final schedule = Schedule(
      id: now.millisecondsSinceEpoch.toString(),
      deviceId: widget.device.id,
      time: DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
      type: _selectedScheduleType,
    );

    setState(() {
      _schedules.add(schedule);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã hẹn giờ lúc ${_timeInputController.text}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeSchedule(Schedule schedule) {
    setState(() {
      _schedules.removeWhere((s) => s.id == schedule.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceInfoCard(),
            const SizedBox(height: 24),
            _buildControlSection(),
            const SizedBox(height: 24),
            _buildScheduleSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.device.status.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.device.type.icon,
              size: 28,
              color: widget.device.status.color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.device.type.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.device.status.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.device.status.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.device.status.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.device.status.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlSection() {
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
          const Text(
            'Điều khiển thiết bị',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bật/Tắt thiết bị',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Switch(
                value: _isOn,
                onChanged: (value) {
                  setState(() {
                    _isOn = value;
                  });
                },
                activeColor: Colors.green,
              ),
              Text(
                _isOn ? 'BẬT' : 'TẮT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isOn ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã làm mới'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Làm mới'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
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
          const Text(
            'Hẹn giờ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _timeInputController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Thời gian',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: _selectTime,
                    ),
                  ),
                  onTap: _selectTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ScheduleType>(
                  value: _selectedScheduleType,
                  decoration: const InputDecoration(
                    labelText: 'Loại',
                    border: OutlineInputBorder(),
                  ),
                  items: ScheduleType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedScheduleType = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Hẹn giờ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_schedules.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Danh sách hẹn giờ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
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
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${schedule.time.hour.toString().padLeft(2, '0')}:${schedule.time.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              schedule.type.displayName,
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
                        onPressed: () => _removeSchedule(schedule),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
