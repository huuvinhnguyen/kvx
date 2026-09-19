import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/usecases/buzzer_usecases.dart';
import '../../domain/entities/buzzer_detail.dart';
import '../../domain/entities/device.dart';
import '../providers/buzzer_provider.dart';

class BuzzerDetailScreen extends StatelessWidget {
  final Device device;
  final BuzzerUseCases useCases;
  const BuzzerDetailScreen({
    super.key,
    required this.device,
    required this.useCases,
  });

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    final brightness = MediaQuery.platformBrightnessOf(context);
    // Scope system appearance to this screen; legacy screens have fixed colors.
    return Theme(
      data: brightness == inherited.brightness
          ? inherited
          : ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: inherited.colorScheme.primary,
                brightness: brightness,
              ),
              useMaterial3: inherited.useMaterial3,
            ),
      child: ChangeNotifierProvider(
        key: ValueKey(device.id),
        create: (_) =>
            BuzzerProvider(deviceId: device.id, useCases: useCases)..load(),
        child: _BuzzerContent(device: device),
      ),
    );
  }
}

class _BuzzerContent extends StatelessWidget {
  final Device device;
  const _BuzzerContent({required this.device});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BuzzerProvider>();
    final detail = model.detail;
    return Scaffold(
      appBar: AppBar(title: Text(device.name)),
      body: RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _card(context, 'THIẾT BỊ CẢNH BÁO', [
              const Icon(Icons.notifications_active_outlined, size: 36),
              Text(device.name, style: Theme.of(context).textTheme.titleLarge),
              SelectableText(device.chipId ?? 'Chưa có mã chip'),
              Text(
                switch (device.status) {
                  DeviceStatus.online => '● Online',
                  DeviceStatus.busy => '● Busy',
                  DeviceStatus.offline => '○ Offline',
                },
                style: TextStyle(
                  color: device.status == DeviceStatus.online
                      ? Colors.green
                      : device.status == DeviceStatus.busy
                      ? Colors.orange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              _value(
                'Lần kết nối cuối',
                formatBuzzerDate(detail?.lastSeen ?? device.lastConnected),
              ),
              if (detail != null)
                OutlinedButton.icon(
                  onPressed: model.isBusy || model.needsLogin
                      ? null
                      : () => model.send(BuzzerCommand.refresh),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới thiết bị'),
                ),
            ]),
            if (model.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tải dữ liệu',
                  ),
                ),
              ),
            if (model.notice != null)
              _card(context, 'Thông báo', [Text(model.notice!)]),
            if (model.errorMessage != null)
              _card(context, 'Dữ liệu mở rộng và điều khiển Buzzer', [
                Text(
                  model.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: model.isBusy ? null : model.load,
                  child: Text(
                    model.needsLogin
                        ? 'Đăng nhập lại Binblog'
                        : 'Tải lại dữ liệu',
                  ),
                ),
              ]),
            if (detail != null) ...[
              _card(context, 'Tổng quan', [
                _value('PIR đang liên kết', '${detail.sources.length}'),
                _value(
                  'Lần trigger gần nhất',
                  formatBuzzerDate(detail.events.firstOrNull?.occurredAt),
                ),
                _value('Thời lượng test', _duration(detail.testDurationMs)),
                FilledButton.icon(
                  onPressed:
                      model.isBusy ||
                          !detail.canTest ||
                          model.cooldownSeconds > 0
                      ? null
                      : () => _confirm(context, model, BuzzerCommand.test),
                  icon: const Icon(Icons.notifications_active),
                  label: Text(
                    model.pendingCommand == BuzzerCommand.test
                        ? 'Đang gửi lệnh…'
                        : model.cooldownSeconds > 0
                        ? 'Chờ ${model.cooldownSeconds} giây'
                        : 'Test Buzzer',
                  ),
                ),
                if (model.pendingCommand != null)
                  const LinearProgressIndicator(semanticsLabel: 'Đang xử lý'),
                if (!detail.canTest)
                  const Text(
                    'Cần cấu hình thời lượng từ 100 đến 10.000 ms để test.',
                  ),
                const Text(
                  'Chỉ xác nhận server đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.',
                ),
              ]),
              _card(context, 'PIR kích hoạt Buzzer (${detail.sources.length})', [
                if (detail.sources.isEmpty)
                  const Text(
                    'Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.',
                  ),
                for (final source in detail.sources)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(source.chipId),
                        Text(
                          'Kênh ${source.relayIndex} · ${_duration(source.durationMs)}',
                        ),
                      ],
                    ),
                  ),
              ]),
              _card(context, 'Lịch sử lệnh từ PIR', [
                const Text(
                  'Tối đa 20 sự kiện gần nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.',
                ),
                if (detail.events.isEmpty)
                  const Text('Chưa có lịch sử lệnh từ PIR cho Buzzer này.'),
                for (final event in detail.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatBuzzerDate(event.occurredAt),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(event.sourceName),
                        Text(event.sourceChipId),
                        Text('${_duration(event.durationMs)} · Đã nhận motion'),
                      ],
                    ),
                  ),
              ]),
              _card(context, 'Thông tin thiết bị', [
                SelectableText(detail.chipId),
                if (detail.buildVersion?.isNotEmpty ?? false)
                  _value('Firmware', 'v${detail.buildVersion}'),
                if (detail.appVersion?.isNotEmpty ?? false)
                  _value('Ứng dụng', 'v${detail.appVersion}'),
              ]),
              _card(context, 'Quản lý thiết bị', [
                OutlinedButton.icon(
                  onPressed: model.isBusy
                      ? null
                      : () => _confirm(context, model, BuzzerCommand.restart),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Khởi động lại thiết bị'),
                ),
                OutlinedButton.icon(
                  onPressed: model.isBusy
                      ? null
                      : () => _confirm(context, model, BuzzerCommand.resetWifi),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.wifi),
                  label: const Text('Thay đổi WiFi'),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: child,
                ),
            ],
          ),
        ),
      );

  Widget _value(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );

  String _duration(int? value) => value == null ? '—' : '$value ms';

  Future<void> _confirm(
    BuildContext context,
    BuzzerProvider model,
    BuzzerCommand command,
  ) async {
    final title = switch (command) {
      BuzzerCommand.test => 'Test Buzzer',
      BuzzerCommand.resetWifi => 'Thay đổi WiFi',
      _ => 'Khởi động lại thiết bị',
    };
    final message = switch (command) {
      BuzzerCommand.test =>
        'Buzzer sẽ phát âm theo thời lượng đã cấu hình. Bạn muốn tiếp tục?',
      BuzzerCommand.resetWifi =>
        'Thiết bị sẽ xóa WiFi cũ và chuyển sang chế độ cấu hình mới. Bạn có chắc không?',
      _ => 'Bạn có chắc muốn khởi động lại thiết bị không?',
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) await model.send(command);
  }
}

String formatBuzzerDate(DateTime? value) {
  if (value == null) return 'Chưa có dữ liệu';
  final date = value.toUtc().add(const Duration(hours: 7));
  String pad(int part) => part.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}';
}
