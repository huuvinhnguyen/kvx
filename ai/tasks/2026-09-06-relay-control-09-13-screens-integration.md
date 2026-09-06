# Task 09-13 — Relay Control Screens and Integration

## Status

Ready to start (depends on Tasks 03, 06, 07-08).

## Goal

Create screens and provider for relay control, integrate with navigation, and wire up dependency injection. Complete user flow from device list to relay control.

## Scope

- Flutter presentation layer integration.
- Create `RelayDeviceProvider` for state management.
- Create `RelayDeviceDetailScreen` with tab view.
- Create `RelayStatisticsScreen`.
- Update navigation in device list.
- Register providers in main.dart.

## Prerequisites

- Task 03 complete: use cases implemented
- Task 06 complete: repository implemented
- Tasks 07-08 complete: UI widgets created
- Understanding of existing provider pattern

## Architecture Decision

**State Management Strategy:**
- Use `ChangeNotifier` provider (matches existing pattern)
- Provider manages loading/error states
- Provider calls use cases (no direct repository access)
- Screens are stateless where possible, observe provider

**Navigation Strategy:**
- Route from device list based on device type
- Pass device object via navigation args
- Statistics screen gets deviceId + relayIndex
- Back navigation works naturally

---

## Task 09: RelayDeviceProvider

### Purpose
Centralized state management for relay control operations.

### Implementation

```dart
// relay_device_provider.dart

import 'package:flutter/foundation.dart';
import '../../application/usecases/toggle_relay_usecase.dart';
import '../../application/usecases/activate_relay_for_duration_usecase.dart';
import '../../application/usecases/manage_relay_reminder_usecase.dart';
import '../../application/usecases/get_relay_statistics_usecase.dart';
import '../../application/usecases/control_device_usecase.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/relay_reminder.dart';
import '../../domain/entities/relay_statistics.dart';

class RelayDeviceProvider extends ChangeNotifier {
  final ToggleRelayUseCase _toggleRelayUseCase;
  final ActivateRelayForDurationUseCase _activateForDurationUseCase;
  final ManageRelayReminderUseCase _manageReminderUseCase;
  final GetRelayStatisticsUseCase _getStatisticsUseCase;
  final ControlDeviceUseCase _controlDeviceUseCase;

  RelayDeviceProvider({
    required ToggleRelayUseCase toggleRelayUseCase,
    required ActivateRelayForDurationUseCase activateForDurationUseCase,
    required ManageRelayReminderUseCase manageReminderUseCase,
    required GetRelayStatisticsUseCase getStatisticsUseCase,
    required ControlDeviceUseCase controlDeviceUseCase,
  })  : _toggleRelayUseCase = toggleRelayUseCase,
        _activateForDurationUseCase = activateForDurationUseCase,
        _manageReminderUseCase = manageReminderUseCase,
        _getStatisticsUseCase = getStatisticsUseCase,
        _controlDeviceUseCase = controlDeviceUseCase;

  Device? _device;
  Map<int, List<RelayReminder>> _remindersByChannel = {};
  Map<int, bool> _remindersActiveByChannel = {};
  int _selectedRelayIndex = 0;
  bool _isLoading = false;
  bool _isToggling = false;
  bool _isActivating = false;
  bool _isManagingReminders = false;
  String? _error;

  Device? get device => _device;
  List<RelayReminder> get currentReminders =>
      _remindersByChannel[_selectedRelayIndex] ?? [];
  bool get areRemindersActive =>
      _remindersActiveByChannel[_selectedRelayIndex] ?? true;
  int get selectedRelayIndex => _selectedRelayIndex;
  bool get isLoading => _isLoading;
  bool get isToggling => _isToggling;
  bool get isActivating => _isActivating;
  bool get isManagingReminders => _isManagingReminders;
  String? get error => _error;

  bool get hasError => _error != null;

  void setDevice(Device device) {
    _device = device;
    _selectedRelayIndex = 0;
    _error = null;
    notifyListeners();
  }

  void selectRelayChannel(int index) {
    _selectedRelayIndex = index;
    _error = null;
    notifyListeners();
  }

  Future<void> toggleRelay(int relayIndex, bool isOn) async {
    if (_device == null) return;

    _isToggling = true;
    _error = null;
    notifyListeners();

    try {
      await _toggleRelayUseCase(
        deviceId: _device!.id,
        relayIndex: relayIndex,
        isOn: isOn,
      );

      // Update local state optimistically
      if (_device!.relayChannels != null) {
        final updatedChannels = List<RelayChannel>.from(_device!.relayChannels!);
        final channelIndex = updatedChannels.indexWhere((c) => c.index == relayIndex);
        if (channelIndex != -1) {
          updatedChannels[channelIndex] = updatedChannels[channelIndex].copyWith(isOn: isOn);
          _device = _device!.copyWith(relayChannels: updatedChannels);
        }
      }
    } catch (e) {
      _error = 'Không thể điều khiển relay: ${e.toString()}';
    } finally {
      _isToggling = false;
      notifyListeners();
    }
  }

  Future<void> activateForDuration(int relayIndex, Duration duration) async {
    if (_device == null) return;

    _isActivating = true;
    _error = null;
    notifyListeners();

    try {
      await _activateForDurationUseCase(
        deviceId: _device!.id,
        relayIndex: relayIndex,
        duration: duration,
      );
    } catch (e) {
      _error = 'Không thể kích hoạt relay: ${e.toString()}';
    } finally {
      _isActivating = false;
      notifyListeners();
    }
  }

  Future<void> loadReminders(int relayIndex) async {
    if (_device == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final reminders = await _manageReminderUseCase.getReminders(
        deviceId: _device!.id,
        relayIndex: relayIndex,
      );
      _remindersByChannel[relayIndex] = reminders;

      // Determine if reminders are active (at least one active)
      _remindersActiveByChannel[relayIndex] =
          reminders.any((r) => r.isActive);
    } catch (e) {
      _error = 'Không thể tải danh sách hẹn giờ: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReminder(RelayReminder reminder) async {
    _isManagingReminders = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _manageReminderUseCase.addReminder(reminder);
      
      final channelReminders = _remindersByChannel[reminder.relayIndex] ?? [];
      _remindersByChannel[reminder.relayIndex] = [...channelReminders, created];
    } catch (e) {
      _error = 'Không thể thêm hẹn giờ: ${e.toString()}';
    } finally {
      _isManagingReminders = false;
      notifyListeners();
    }
  }

  Future<void> removeReminder(String reminderId, int relayIndex) async {
    _isManagingReminders = true;
    _error = null;
    notifyListeners();

    try {
      await _manageReminderUseCase.removeReminder(reminderId);
      
      final channelReminders = _remindersByChannel[relayIndex] ?? [];
      _remindersByChannel[relayIndex] =
          channelReminders.where((r) => r.id != reminderId).toList();
    } catch (e) {
      _error = 'Không thể xóa hẹn giờ: ${e.toString()}';
    } finally {
      _isManagingReminders = false;
      notifyListeners();
    }
  }

  Future<void> toggleReminders(int relayIndex, bool isActive) async {
    if (_device == null) return;

    _isManagingReminders = true;
    _error = null;
    notifyListeners();

    try {
      await _manageReminderUseCase.toggleReminders(
        deviceId: _device!.id,
        relayIndex: relayIndex,
        isActive: isActive,
      );

      _remindersActiveByChannel[relayIndex] = isActive;

      // Update local reminder states
      final channelReminders = _remindersByChannel[relayIndex] ?? [];
      _remindersByChannel[relayIndex] = channelReminders
          .map((r) => r.copyWith(isActive: isActive))
          .toList();
    } catch (e) {
      _error = 'Không thể bật/tắt hẹn giờ: ${e.toString()}';
    } finally {
      _isManagingReminders = false;
      notifyListeners();
    }
  }

  Future<void> refreshDevice() async {
    if (_device == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _controlDeviceUseCase.refresh(_device!.id);
      _device = updated;
    } catch (e) {
      _error = 'Không thể làm mới thiết bị: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restartDevice() async {
    if (_device == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _controlDeviceUseCase.restart(_device!.id);
    } catch (e) {
      _error = 'Không thể khởi động lại thiết bị: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetWifi() async {
    if (_device == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _controlDeviceUseCase.resetWifi(_device!.id);
    } catch (e) {
      _error = 'Không thể reset WiFi: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
```

---

## Task 10: RelayDeviceDetailScreen

### Implementation

```dart
// relay_device_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/relay_reminder.dart';
import '../providers/relay_device_provider.dart';
import '../widgets/device_info_header.dart';
import '../widgets/relay_toggle_switch.dart';
import '../widgets/relay_longlast_form.dart';
import '../widgets/relay_reminder_form.dart';
import '../widgets/relay_reminder_list.dart';
import '../widgets/device_control_footer.dart';
import 'relay_statistics_screen.dart';

class RelayDeviceDetailScreen extends StatefulWidget {
  final Device device;

  const RelayDeviceDetailScreen({
    super.key,
    required this.device,
  });

  @override
  State<RelayDeviceDetailScreen> createState() =>
      _RelayDeviceDetailScreenState();
}

class _RelayDeviceDetailScreenState extends State<RelayDeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    
    final relayCount = widget.device.relayCount ?? 2;
    _tabController = TabController(length: relayCount, vsync: this);
    
    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RelayDeviceProvider>();
      provider.setDevice(widget.device);
      provider.loadReminders(0); // Load reminders for first channel
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final provider = context.read<RelayDeviceProvider>();
        provider.selectRelayChannel(_tabController.index);
        provider.loadReminders(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: List.generate(
            widget.device.relayCount ?? 2,
            (index) => Tab(text: 'Kênh ${index + 1}'),
          ),
        ),
      ),
      body: Consumer<RelayDeviceProvider>(
        builder: (context, provider, child) {
          if (provider.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error!),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'Đóng',
                    textColor: Colors.white,
                    onPressed: () => provider.clearError(),
                  ),
                ),
              );
              provider.clearError();
            });
          }

          return TabBarView(
            controller: _tabController,
            children: List.generate(
              widget.device.relayCount ?? 2,
              (index) => _buildRelayChannelTab(context, provider, index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRelayChannelTab(
    BuildContext context,
    RelayDeviceProvider provider,
    int relayIndex,
  ) {
    final device = provider.device ?? widget.device;
    final relayChannel = device.relayChannels?.firstWhere(
      (c) => c.index == relayIndex,
      orElse: () => RelayChannel(index: relayIndex, isOn: false),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device info header
          DeviceInfoHeader(device: device),
          const SizedBox(height: 24),

          // Toggle switch
          RelayToggleSwitch(
            isOn: relayChannel?.isOn ?? false,
            isLoading: provider.isToggling,
            onChanged: (value) => provider.toggleRelay(relayIndex, value),
          ),
          const SizedBox(height: 24),

          // Longlast form
          RelayLonglastForm(
            isLoading: provider.isActivating,
            onActivate: (duration) {
              provider.activateForDuration(relayIndex, duration);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Relay sẽ tự động tắt sau ${duration.inSeconds} giây',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Statistics button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RelayStatisticsScreen(
                      deviceId: device.id,
                      relayIndex: relayIndex,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('📊 Xem thống kê'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Reminder form
          RelayReminderForm(
            isLoading: provider.isManagingReminders,
            onAdd: (formData) {
              final reminder = RelayReminder(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                deviceId: device.id,
                relayIndex: relayIndex,
                startTime: formData.startTime,
                duration: formData.duration,
                repeatType: formData.repeatType,
                isActive: true,
              );
              provider.addReminder(reminder);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã thêm hẹn giờ')),
              );
            },
          ),
          const SizedBox(height: 24),

          // Reminder list
          RelayReminderList(
            reminders: provider.currentReminders,
            areRemindersActive: provider.areRemindersActive,
            onToggleAll: (isActive) {
              provider.toggleReminders(relayIndex, isActive);
            },
            onDelete: (reminderId) {
              provider.removeReminder(reminderId, relayIndex);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa hẹn giờ')),
              );
            },
          ),
          const SizedBox(height: 24),

          // Device control footer
          DeviceControlFooter(
            deviceId: device.id,
            firmwareVersion: device.firmwareVersion,
            appVersion: device.appVersion,
            onRefresh: () {
              provider.refreshDevice();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã làm mới')),
              );
            },
            onRestart: () async {
              await provider.restartDevice();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang khởi động lại...')),
                );
              }
            },
            onResetWifi: () async {
              await provider.resetWifi();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thiết bị đang chuyển sang chế độ cấu hình WiFi'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
```

---

## Task 11: RelayStatisticsScreen

### Implementation

```dart
// relay_statistics_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/usecases/get_relay_statistics_usecase.dart';
import '../../domain/entities/relay_statistics.dart';
import '../extensions/duration_extensions.dart';

class RelayStatisticsScreen extends StatefulWidget {
  final String deviceId;
  final int relayIndex;

  const RelayStatisticsScreen({
    super.key,
    required this.deviceId,
    required this.relayIndex,
  });

  @override
  State<RelayStatisticsScreen> createState() => _RelayStatisticsScreenState();
}

class _RelayStatisticsScreenState extends State<RelayStatisticsScreen> {
  late Future<RelayStatistics> _statisticsFuture;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    final useCase = context.read<GetRelayStatisticsUseCase>();
    _statisticsFuture = useCase(
      deviceId: widget.deviceId,
      relayIndex: widget.relayIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thống kê Kênh ${widget.relayIndex + 1}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadStatistics();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<RelayStatistics>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Không thể tải thống kê',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loadStatistics();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('Chưa có dữ liệu thống kê'),
            );
          }

          final stats = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatCard(
                  icon: Icons.access_time,
                  iconColor: Colors.blue,
                  title: 'Tổng thời gian bật',
                  value: stats.totalOnTime.toVietnamese(),
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.power_settings_new,
                  iconColor: Colors.green,
                  title: 'Số lần kích hoạt',
                  value: '${stats.activationCount} lần',
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.schedule,
                  iconColor: Colors.orange,
                  title: 'Lần kích hoạt cuối',
                  value: stats.lastActivated != null
                      ? _formatDateTime(stats.lastActivated!)
                      : 'Chưa có',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    String relative;
    if (difference.inMinutes < 1) {
      relative = 'Vừa xong';
    } else if (difference.inHours < 1) {
      relative = '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      relative = '${difference.inHours} giờ trước';
    } else {
      relative = '${difference.inDays} ngày trước';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')} ($relative)';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Task 12: Navigation Integration

### Modify device_list_screen.dart

```dart
// Update device row onTap logic

import 'relay_device_detail_screen.dart';

// In device row widget:
onTap: () {
  if (device.type == DeviceType.switchDevice && device.relayCount != null) {
    // Navigate to relay control screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RelayDeviceDetailScreen(device: device),
      ),
    );
  } else {
    // Navigate to existing device detail screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(device: device),
      ),
    );
  }
},
```

---

## Task 13: Provider Registration in main.dart

### Modify main.dart

```dart
import 'package:provider/provider.dart';

// ... existing imports ...
import 'application/usecases/toggle_relay_usecase.dart';
import 'application/usecases/activate_relay_for_duration_usecase.dart';
import 'application/usecases/manage_relay_reminder_usecase.dart';
import 'application/usecases/get_relay_statistics_usecase.dart';
import 'application/usecases/control_device_usecase.dart';
import 'presentation/providers/relay_device_provider.dart';

void main() {
  // ... existing datasource and repository setup ...
  
  final deviceRepository = DeviceRepositoryImpl(dataSource);
  
  runApp(
    MultiProvider(
      providers: [
        // Existing providers
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(
            getDevicesUseCase: GetDevicesUseCase(deviceRepository),
            addDeviceUseCase: AddDeviceUseCase(deviceRepository),
            deleteDeviceUseCase: DeleteDeviceUseCase(deviceRepository),
            toggleStatusUseCase: ToggleDeviceStatusUseCase(deviceRepository),
          ),
        ),
        
        // NEW: Relay control provider
        ChangeNotifierProvider(
          create: (_) => RelayDeviceProvider(
            toggleRelayUseCase: ToggleRelayUseCase(deviceRepository),
            activateForDurationUseCase: ActivateRelayForDurationUseCase(deviceRepository),
            manageReminderUseCase: ManageRelayReminderUseCase(deviceRepository),
            getStatisticsUseCase: GetRelayStatisticsUseCase(deviceRepository),
            controlDeviceUseCase: ControlDeviceUseCase(deviceRepository),
          ),
        ),
        
        // NEW: Provide use case directly for statistics screen
        Provider(
          create: (_) => GetRelayStatisticsUseCase(deviceRepository),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
```

---

## Acceptance Criteria

- [ ] RelayDeviceProvider compiles and manages state correctly
- [ ] RelayDeviceDetailScreen renders with tabs
- [ ] Tab switching loads reminders for each channel
- [ ] All widgets integrated and callbacks wired
- [ ] RelayStatisticsScreen loads and displays stats
- [ ] Navigation from device list works (routes to correct screen)
- [ ] Providers registered in main.dart
- [ ] Error states show SnackBar messages
- [ ] Loading states disable controls appropriately
- [ ] Back navigation works correctly
- [ ] Manual test: complete user flow works end-to-end

## Verification

```bash
cd kvx_flutter
flutter run
```

Manual test checklist:
- [ ] Open device list
- [ ] Tap relay device
- [ ] See relay detail screen with tabs
- [ ] Toggle relay on/off
- [ ] Activate relay for duration (shows success message)
- [ ] Add reminder (appears in list)
- [ ] Delete reminder (removed from list)
- [ ] Toggle all reminders on/off
- [ ] Navigate to statistics (shows data)
- [ ] Go back to detail
- [ ] Refresh device
- [ ] Restart device (with confirmation)
- [ ] Reset WiFi (with confirmation)
- [ ] Test error scenarios (network off)

## Implementation Notes

### Provider Lifecycle

- Provider created once at app startup
- `setDevice()` called when entering screen
- State persists across navigation (back button)
- Clear errors after showing SnackBar

### Tab Controller

- Number of tabs = device.relayCount
- Load reminders when tab changes
- Dispose controller in state dispose

### Error Handling

```dart
// In provider: set error
_error = 'Message';
notifyListeners();

// In screen: show SnackBar
if (provider.hasError) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    provider.clearError();
  });
}
```

### Success Feedback

Show SnackBar for user actions:
- Toggle relay: implicit feedback (switch state)
- Activate longlast: "Relay sẽ tự động tắt sau X giây"
- Add reminder: "Đã thêm hẹn giờ"
- Delete reminder: "Đã xóa hẹn giờ"
- Refresh: "Đã làm mới"

## Risks / Limitations

- **Risk**: State inconsistency across tabs
  - **Mitigation**: Load reminders on tab change

- **Risk**: Memory leak (TabController not disposed)
  - **Mitigation**: Dispose in state dispose method

- **Risk**: Provider state persists across devices
  - **Mitigation**: Call `setDevice()` on screen enter

- **Limitation**: No realtime relay state updates
  - **Rationale**: MVP uses manual refresh

## Out of Scope

- Realtime updates (WebSocket)
- Push notifications for reminders
- Offline queue for actions
- Undo/redo functionality
- Animation between states

## Follow-Up Tasks

After completion:
- Task 14: Integration testing (full flow)
- Task 15: UI polish and accessibility
- Task 16: Documentation
