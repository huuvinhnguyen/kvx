import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/usecases/buzzer_usecases.dart';
import '../../domain/entities/device.dart';
import '../providers/buzzer_provider.dart';

class BuzzerDetailScreen extends StatelessWidget {
  final Device device;
  final BuzzerUseCases useCases;
  const BuzzerDetailScreen({super.key, required this.device, required this.useCases});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    key: ValueKey(device.id),
    create: (_) => BuzzerProvider(deviceId: device.id, useCases: useCases)..load(),
    child: _BuzzerContent(device: device),
  );
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
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16),
          children: [
            _card(context, 'THIẾT BỊ CẢNH BÁO', [
              const Icon(Icons.notifications_active_outlined, size: 36),
              Text(device.name, style: Theme.of(context).textTheme.titleLarge),
              SelectableText(device.chipId ?? 'Chưa có mã chip'),
              Text(switch (device.status) { DeviceStatus.online => '● Online', DeviceStatus.busy => '● Busy', DeviceStatus.offline => '○ Offline' }, style: TextStyle(color: device.status == DeviceStatus.online ? Colors.green : device.status == DeviceStatus.busy ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant)),
              _value('Lần kết nối cuối', formatBuzzerDate(detail?.lastSeen ?? device.lastConnected)),
            ]),
            if (model.isLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(semanticsLabel: 'Đang tải dữ liệu'))),
            if (model.notice != null) _card(context, 'Thông báo', [Text(model.notice!)]),
            if (model.errorMessage != null) _card(context, 'Dữ liệu mở rộng và điều khiển Buzzer', [Text(model.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)), TextButton(onPressed: model.isBusy ? null : model.load, child: Text(model.needsLogin ? 'Đăng nhập lại Binblog' : 'Tải lại dữ liệu'))]),
            if (detail != null) ...[
              _card(context, 'Tổng quan', [
                _value('PIR đang liên kết', '${detail.linkedPirCount}'),
                _value('Lần trigger gần nhất', formatBuzzerDate(detail.lastTriggeredAt)),
                FilledButton.icon(onPressed: model.isBusy || model.cooldownSeconds > 0 ? null : () => _confirm(context, model), icon: const Icon(Icons.notifications_active), label: Text(model.isTesting ? 'Đang gửi lệnh…' : model.cooldownSeconds > 0 ? 'Chờ ${model.cooldownSeconds} giây' : 'Test Buzzer')),
                if (model.isTesting) const LinearProgressIndicator(semanticsLabel: 'Đang xử lý'),
                const Text('Chỉ xác nhận server đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.'),
              ]),
              _card(context, 'PIR kích hoạt Buzzer (${model.sources.length})', [
                if (model.sources.isEmpty) const Text('Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.'),
                for (final source in model.sources) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(source.name, style: Theme.of(context).textTheme.titleMedium), Text(source.chipId), Text('Kênh ${source.relayIndex} · ${_duration(source.longlast)}')]))
              ]),
              _card(context, 'Lịch sử lệnh từ PIR', [
                const Text('Tối đa 20 sự kiện mới nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.'),
                if (model.events.isEmpty) const Text('Chưa có lịch sử lệnh từ PIR cho Buzzer này.'),
                for (final event in model.events) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(formatBuzzerDate(event.occurredAt), style: Theme.of(context).textTheme.titleMedium), Text(event.sourceName), Text(event.sourceChipId), Text('Kênh ${event.relayIndex} · ${_duration(event.longlast)} · Đã nhận motion')]))
              ]),
              _card(context, 'Thông tin thiết bị', [SelectableText(detail.chipId)]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) => Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 8), child: child)])));
  Widget _value(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]);
  String _duration(int? value) => value == null ? '—' : '$value ms';
  Future<void> _confirm(BuildContext context, BuzzerProvider model) async {
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Test Buzzer'), content: const Text('Buzzer sẽ phát âm theo cấu hình trên máy chủ. Bạn muốn tiếp tục?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')), TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xác nhận'))]));
    if (accepted == true && context.mounted) await model.test();
  }
}

String formatBuzzerDate(DateTime? value) { if (value == null) return 'Chưa có dữ liệu'; final date = value.toUtc().add(const Duration(hours: 7)); String pad(int part) => part.toString().padLeft(2, '0'); return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}'; }
