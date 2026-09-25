import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/usecases/buzzer_usecases.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/buzzer_detail.dart';
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
  Widget build(BuildContext context) => ChangeNotifierProvider(
    key: ValueKey(device.id),
    create: (_) =>
        BuzzerProvider(deviceId: device.id, useCases: useCases)..load(),
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
                _value('PIR đang liên kết', '${detail.linkedPirCount}'),
                _value(
                  'Lần trigger gần nhất',
                  formatBuzzerDate(detail.lastTriggeredAt),
                ),
                FilledButton.icon(
                  onPressed: model.isBusy || model.cooldownSeconds > 0
                      ? null
                      : () => _confirm(context, model),
                  icon: const Icon(Icons.notifications_active),
                  label: Text(
                    model.isTesting
                        ? 'Đang gửi lệnh…'
                        : model.cooldownSeconds > 0
                        ? 'Chờ ${model.cooldownSeconds} giây'
                        : 'Test Buzzer',
                  ),
                ),
                if (model.isTesting)
                  const LinearProgressIndicator(semanticsLabel: 'Đang xử lý'),
                const Text(
                  'Chỉ xác nhận server đã gửi lệnh đến MQTT broker; chưa có xác nhận từ Buzzer.',
                ),
              ]),
              _card(context, 'PIR kích hoạt Buzzer (${model.sources.length})', [
                FilledButton(
                  onPressed: model.isBusy || model.requiresRefresh
                      ? null
                      : () => _openLinks(context, model),
                  child: const Text('+ Liên kết PIR'),
                ),
                if (model.isLoading) const LinearProgressIndicator(),
                if (model.sources.isEmpty)
                  const Text(
                    'Chưa có PIR nào được cấu hình để kích hoạt Buzzer này.',
                  ),
                for (final source in model.sources)
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
                          'Kênh ${_scalar(source.relayDisplay, source.relayIndex)} · ${_duration(source.longlast, source.longlastDisplay)}',
                        ),
                        TextButton(
                          onPressed: model.isBusy || model.requiresRefresh
                              ? null
                              : () => _unlink(context, model, source),
                          child: Text('Hủy liên kết ${source.name}'),
                        ),
                      ],
                    ),
                  ),
              ]),
              _card(context, 'Lịch sử lệnh từ PIR', [
                const Text(
                  'Tối đa 20 sự kiện mới nhất. Thời gian Việt Nam (UTC+7). Đã nhận motion không có nghĩa Buzzer đã phát âm.',
                ),
                if (model.events.isEmpty)
                  const Text('Chưa có lịch sử lệnh từ PIR cho Buzzer này.'),
                for (final event in model.events)
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
                        Text(
                          'Kênh ${_scalar(event.relayDisplay, event.relayIndex)} · ${_duration(event.longlast, event.longlastDisplay)} · Đã nhận motion',
                        ),
                      ],
                    ),
                  ),
              ]),
              _card(context, 'Thông tin thiết bị', [
                SelectableText(detail.chipId),
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
  String _scalar(String? display, int? value) =>
      display ?? value?.toString() ?? '—';
  String _duration(int? value, String? display) => display != null
      ? '$display ms'
      : value == null
      ? '—'
      : '$value ms';
  Future<void> _openLinks(BuildContext context, BuzzerProvider model) async {
    await model.loadAvailable();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: model,
        child: _LinkPirSheet(deviceId: device.id),
      ),
    );
  }

  Future<void> _unlink(
    BuildContext context,
    BuzzerProvider model,
    BuzzerSource source,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Hủy liên kết'),
        content: const Text(
          'PIR sẽ ngừng kích hoạt Buzzer này. Hủy liên kết chỉ thay đổi cấu hình, không phát âm hoặc chạy Test Buzzer. Tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Hủy liên kết'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) await model.unlink(source.id);
  }

  Future<void> _confirm(BuildContext context, BuzzerProvider model) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test Buzzer'),
        content: const Text(
          'Buzzer sẽ phát âm theo cấu hình trên máy chủ. Bạn muốn tiếp tục?',
        ),
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
    if (accepted == true && context.mounted) await model.test();
  }
}

String formatBuzzerDate(DateTime? value) {
  if (value == null) return 'Chưa có dữ liệu';
  final date = value.toUtc().add(const Duration(hours: 7));
  String pad(int part) => part.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}:${pad(date.second)}';
}

class _LinkPirSheet extends StatefulWidget {
  final String deviceId;
  const _LinkPirSheet({required this.deviceId});
  @override
  State<_LinkPirSheet> createState() => _LinkPirSheetState();
}

class _LinkPirSheetState extends State<_LinkPirSheet> {
  String? selectedId;
  final relay = TextEditingController(text: '0');
  final duration = TextEditingController(text: '1000');
  @override
  void dispose() {
    relay.dispose();
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BuzzerProvider>();
    final selected = model.availablePirs
        .where((pir) => pir.id == selectedId)
        .firstOrNull;
    final warning = selected?.confirmation(widget.deviceId);
    final configuration = BuzzerLinkConfiguration(
      selectedId ?? '',
      int.tryParse(relay.text) ?? -1,
      int.tryParse(duration.text) ?? -1,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Liên kết PIR',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (model.isLoadingAvailable) const LinearProgressIndicator(),
              if (model.availableError != null) ...[
                Text(model.availableError!),
                TextButton(
                  onPressed: model.loadAvailable,
                  child: const Text('Thử lại'),
                ),
              ],
              if (!model.isLoadingAvailable &&
                  model.availableError == null) ...[
                if (model.availablePirs.isEmpty)
                  const Text('Không có PIR nào khả dụng.'),
                if (model.availablePirs.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'PIR'),
                    items: [
                      for (final pir in model.availablePirs)
                        DropdownMenuItem(
                          value: pir.id,
                          child: Text(pir.displayName),
                        ),
                    ],
                    onChanged: model.isMutating
                        ? null
                        : (value) {
                            setState(() {
                              selectedId = value;
                              final existing = model.sources
                                  .where((source) => source.id == value)
                                  .firstOrNull;
                              relay.text = '${existing?.relayIndex ?? 0}';
                              duration.text = '${existing?.longlast ?? 1000}';
                            });
                          },
                  ),
                TextField(
                  controller: relay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kênh relay (từ 0)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (100–10000 ms)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (warning != null) Text(warning),
                const Text(
                  'Liên kết chỉ thay đổi cấu hình; không chạy Test Buzzer hoặc phát âm.',
                ),
                FilledButton(
                  onPressed:
                      model.isBusy ||
                          model.requiresRefresh ||
                          !configuration.isValid
                      ? null
                      : () async {
                          if (warning != null) {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: const Text('Xác nhận liên kết'),
                                content: Text(warning),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: Text(
                                      selected?.linkedBuzzer != null
                                          ? 'Chuyển & liên kết'
                                          : 'Thay thế & liên kết',
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (accepted != true || !context.mounted) return;
                          }
                          await model.link(configuration);
                          if (context.mounted &&
                              model.errorMessage == null &&
                              !model.requiresRefresh) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Liên kết'),
                ),
              ],
              if (model.isMutating) const LinearProgressIndicator(),
              if (model.errorMessage != null)
                Text(
                  model.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
