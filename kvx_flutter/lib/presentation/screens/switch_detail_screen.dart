import 'package:flutter/material.dart';
import '../../application/usecases/switch_use_cases.dart';
import '../../domain/entities/switch_detail.dart';
import '../providers/switch_provider.dart';

class SwitchDetailScreen extends StatefulWidget {
  final String deviceId;
  final SwitchUseCases useCases;
  const SwitchDetailScreen({
    super.key,
    required this.deviceId,
    required this.useCases,
  });
  @override
  State<SwitchDetailScreen> createState() => _SwitchDetailScreenState();
}

class _SwitchDetailScreenState extends State<SwitchDetailScreen> {
  late SwitchProvider model;
  final duration = TextEditingController(text: '1');
  bool minutes = false;
  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    model = SwitchProvider(
      deviceId: widget.deviceId,
      useCases: widget.useCases,
    );
    model.addListener(_changed);
    model.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SwitchDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId ||
        oldWidget.useCases != widget.useCases) {
      model.removeListener(_changed);
      model.dispose();
      _create();
    }
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    duration.dispose();
    super.dispose();
  }

  String _time(DateTime date) =>
      '${date.toUtc().add(const Duration(hours: 7)).toIso8601String().replaceFirst('T', ' ').substring(0, 19)} UTC+07';
  String _reminderTime(String? raw) {
    final date = switchTimestamp(raw);
    return date == null ? 'Ngày giờ không hợp lệ' : _time(date);
  }

  Future<void> _sendPulse() async {
    final ms = switchDurationMs(duration.text, minutes: minutes);
    if (ms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nhập số nguyên: 1–86400 giây hoặc 1–1440 phút.'),
        ),
      );
      return;
    }
    await model.pulse(ms);
  }

  @override
  Widget build(BuildContext context) {
    final d = model.detail;
    final relay = d?.relays
        .where((r) => r.index == model.selectedRelay)
        .firstOrNull;
    final rows = [...model.reminders]
      ..sort((a, b) {
        final ad = switchTimestamp(a.startTime),
            bd = switchTimestamp(b.startTime);
        final t = ad == null
            ? (bd == null ? 0 : -1)
            : (bd == null ? 1 : ad.compareTo(bd));
        return t != 0 ? t : BigInt.parse(a.id).compareTo(BigInt.parse(b.id));
      });
    return Scaffold(
      appBar: AppBar(title: Text(d?.name ?? 'Switch')),
      body: RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (model.isBusy)
              const LinearProgressIndicator(semanticsLabel: 'Đang xử lý'),
            const Text('Snapshot máy chủ · Chưa xác minh trạng thái vật lý'),
            const Text('Kết nối thiết bị: chưa xác định'),
            Text(
              'Lần liên lạc: ${d?.lastSeen == null ? 'Chưa xác định' : _time(d!.lastSeen!)}',
            ),
            if (model.errorMessage != null)
              Text(model.errorMessage!, key: const Key('switch-error')),
            if (model.notice != null) Text(model.notice!),
            TextButton(
              onPressed: model.isBusy ? null : model.load,
              child: const Text('Tải lại snapshot'),
            ),
            if (model.uncertain) ...[
              const Text(
                'Kết quả lệnh chưa xác định. Tải lại không chứng minh thiết bị đã bật/tắt. Không tự gửi lại.',
              ),
              TextButton(
                onPressed:
                    model.readReady && !model.isBusy && !model.commandInFlight
                    ? model.acknowledgePhysicalCheck
                    : null,
                child: const Text(
                  'Tôi đã kiểm tra thiết bị, cho phép lệnh mới',
                ),
              ),
            ],
            if (d != null && d.relays.isEmpty)
              const Text('Switch chưa có relay.'),
            if (d != null && d.relays.isNotEmpty)
              DropdownButton<int>(
                value: model.selectedRelay,
                isExpanded: true,
                items: d.relays
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.index,
                        child: Text('Relay ${r.index + 1}'),
                      ),
                    )
                    .toList(),
                onChanged: model.isBusy
                    ? null
                    : (r) {
                        if (r != null) model.selectRelay(r);
                      },
              ),
            if (relay != null) ...[
              Text(
                'Trạng thái snapshot: ${relay.switchValue == null
                    ? 'Chưa xác định'
                    : relay.switchValue == 1
                    ? 'BẬT'
                    : 'TẮT'}',
              ),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: model.canCommand && d!.manualSwitch
                        ? () => model.state(1)
                        : null,
                    child: const Text('BẬT'),
                  ),
                  OutlinedButton(
                    onPressed: model.canCommand && d!.manualSwitch
                        ? () => model.state(0)
                        : null,
                    child: const Text('TẮT'),
                  ),
                ],
              ),
              TextField(
                controller: duration,
                enabled: !model.isBusy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Thời lượng kích hoạt (số nguyên)',
                ),
              ),
              DropdownButton<bool>(
                value: minutes,
                items: const [
                  DropdownMenuItem(value: false, child: Text('Giây')),
                  DropdownMenuItem(value: true, child: Text('Phút')),
                ],
                onChanged: model.isBusy
                    ? null
                    : (v) => setState(() => minutes = v ?? false),
              ),
              FilledButton(
                onPressed: model.canCommand && d!.pulse ? _sendPulse : null,
                child: const Text('Kích hoạt'),
              ),
              const Divider(),
              const Text('Hẹn giờ — chỉ đọc'),
              const Text('Thêm, sửa, xóa và bật/tắt hẹn giờ chưa khả dụng.'),
              Text(
                'Nhóm lịch: ${relay.remindersActive == null
                    ? 'Chưa xác định'
                    : relay.remindersActive!
                    ? 'Đang bật'
                    : 'Đang tắt'}',
              ),
              if (model.readReady && rows.isEmpty)
                const Text('Chưa có hẹn giờ.'),
              for (final r in rows)
                ListTile(
                  title: Text(_reminderTime(r.startTime)),
                  subtitle: Text(
                    '${r.durationMs == null ? 'Thời lượng không hợp lệ' : '${r.durationMs} ms'} · ${switch (r.repeatType) {
                      'once' || 'none' => 'Không lặp',
                      'daily' => 'Hằng ngày',
                      'weekly' => 'Hằng tuần',
                      'monthly' => 'Hằng tháng',
                      _ => 'Kiểu lặp không hỗ trợ',
                    }} · ${r.enabled ? 'Bật' : 'Tắt'}${r.configurationValid ? '' : ' · Cấu hình không hợp lệ'}',
                  ),
                ),
              if (model.nextAfterId != null)
                TextButton(
                  onPressed: model.isBusy ? null : model.moreReminders,
                  child: const Text('Tải thêm hẹn giờ'),
                ),
              if (model.statistics case final stats?) ...[
                const Divider(),
                const Text('Thống kê bản ghi log · UTC+07'),
                Text(
                  '${stats.from} – ${stats.to}: ${stats.totalRecords} bản ghi',
                ),
                const Text('Không phải số lần bật hoặc thời gian chạy vật lý.'),
                for (final day in stats.days)
                  ListTile(
                    title: Text(day.date),
                    trailing: Text('${day.count}'),
                  ),
              ],
            ],
            if (d != null)
              OutlinedButton(
                onPressed: model.canCommand && d.refresh
                    ? model.refreshDevice
                    : null,
                child: const Text('Gửi yêu cầu thiết bị cập nhật'),
              ),
          ],
        ),
      ),
    );
  }
}
