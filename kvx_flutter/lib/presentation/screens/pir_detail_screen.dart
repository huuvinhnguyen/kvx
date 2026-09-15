import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/binblog_device_datasource.dart';
import '../../data/repositories/pir_repository.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/pir_statistics.dart';
import '../extensions/device_presentation.dart';

class PirDetailScreen extends StatefulWidget {
  final Device device;
  final PirRepository? repository;
  const PirDetailScreen({super.key, required this.device, this.repository});
  @override
  State<PirDetailScreen> createState() => _PirDetailScreenState();
}

class _PirDetailScreenState extends State<PirDetailScreen> {
  static const accent = Color(0xff34d399);
  static const levels = [
    Color(0xff292929),
    Color(0xff1d4d42),
    Color(0xff28705d),
    Color(0xff3b9b7a),
    accent,
  ];
  late PirRepository _repository;
  DateTime _date = pirToday();
  PirStatistics? _stats;
  List<PirDay> _days = [];
  List<PirMotionEvent>? _events;
  bool _loading = false;
  String? _error;
  int? _hour;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        BinblogPirRepository(context.read<BinblogDeviceDataSource>());
    _load();
  }

  Future<void> _load() async {
    final request = ++_generation;
    final chipId = widget.device.chipId;
    setState(() {
      _loading = true;
      _error = null;
      _stats = null;
      _hour = null;
    });
    if (chipId == null || chipId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Thiết bị chưa có mã chip. Hãy tải lại danh sách thiết bị.';
      });
      return;
    }
    try {
      final results = await Future.wait<Object>([
        _repository.statistics(chipId, pirDateKey(_date)),
        _repository.heatmap(chipId),
      ]);
      if (!mounted || request != _generation) return;
      setState(() {
        _stats = results[0] as PirStatistics;
        _events = _stats!.recentEvents;
        _days = results[1] as List<PirDay>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _generation) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _select(DateTime date) {
    setState(() => _date = date);
    _load();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff091112),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
    ),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Thiết bị PIR'),
          actions: [
            IconButton(
              tooltip: 'Làm mới',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _card([
                const Row(
                  children: [
                    Icon(Icons.sensors, color: accent),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'CẢM BIẾN CHUYỂN ĐỘNG',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.device.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: widget.device.status.color,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.device.status.displayName),
                    const Spacer(),
                    const Text('PIR'),
                  ],
                ),
                Text(
                  widget.device.chipId ?? 'Chưa có mã chip',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
              _card([
                _title('Phát hiện chuyển động'),
                _hint('Thống kê theo giờ • Giờ Việt Nam (UTC+7)'),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Ngày trước',
                      onPressed: () => _select(
                        DateTime(_date.year, _date.month, _date.day - 1),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: pirToday(),
                          );
                          if (date != null && mounted) _select(date);
                        },
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: Text(
                          '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ngày sau',
                      onPressed: _date.isBefore(pirToday())
                          ? () => _select(
                              DateTime(_date.year, _date.month, _date.day + 1),
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                if (_loading)
                  const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else if (_stats != null) ...[
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_stats!.total} ',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        const TextSpan(
                          text: 'lần phát hiện',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  _chart(_stats!),
                  if (_stats!.total == 0)
                    _hint('Không có chuyển động trong ngày này.'),
                ],
              ]),
              _card([
                _title('Mật độ phát hiện — 30 ngày'),
                _hint('Chạm một ngày để xem biểu đồ theo giờ.'),
                if (_days.isEmpty) _hint('Chưa tải được mật độ chuyển động.'),
                LayoutBuilder(
                  builder: (context, bounds) => Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _days.map((day) {
                      final selected = day.date == pirDateKey(_date);
                      return SizedBox(
                        width: (bounds.maxWidth - 30) / 6,
                        child: Semantics(
                          selected: selected,
                          label: '${day.date}: ${day.count} lần phát hiện',
                          child: Tooltip(
                            message: '${day.date}: ${day.count} lần',
                            child: InkWell(
                              key: ValueKey('day-${day.date}'),
                              onTap: () => _select(DateTime.parse(day.date)),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 52,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: levels[day.level],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${day.date.substring(8)}/${day.date.substring(5, 7)}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Text(
                                      '${day.count}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('0', style: TextStyle(fontSize: 11)),
                    ...levels.map(
                      (color) => Container(
                        width: 18,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const Text('16+ lần', style: TextStyle(fontSize: 11)),
                  ],
                ),
                _hint('Mức màu: 0 · 1–3 · 4–8 · 9–15 · 16+ lần'),
              ]),
              _card([
                _title('Lịch sử chuyển động'),
                _hint('20 sự kiện mới nhất'),
                if (_events == null)
                  _hint('Lịch sử chi tiết chưa khả dụng trên ứng dụng.')
                else if (_events!.isEmpty)
                  _hint('Chưa có sự kiện chuyển động.')
                else
                  ..._events!.map(
                    (event) => Row(
                      children: [
                        const Icon(Icons.directions_walk, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Phát hiện chuyển động'),
                              _hint('${event.displayTime} (UTC+7)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _chart(PirStatistics stats) {
    final maximum = math.max(1, stats.values.reduce(math.max));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hint('$maximum lần'),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (hour) {
              final label =
                  '${hour.toString().padLeft(2, '0')}:00–${(hour + 1).toString().padLeft(2, '0')}:00: ${stats.values[hour]} lần';
              return Expanded(
                child: Semantics(
                  label: label,
                  button: true,
                  child: Tooltip(
                    message: label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _hour = hour),
                      child: Container(
                        height: 160,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: stats.values[hour] / maximum * 160,
                          decoration: BoxDecoration(
                            color: _hour == hour ? Colors.white : accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 1),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00'),
            Text('06'),
            Text('12'),
            Text('18'),
            Text('23'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _hour == null
              ? 'Chạm một cột để xem số lần.'
              : '${_hour!.toString().padLeft(2, '0')}:00–${(_hour! + 1).toString().padLeft(2, '0')}:00: ${stats.values[_hour!]} lần',
          style: const TextStyle(fontSize: 12, color: accent),
        ),
      ],
    );
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
  Widget _hint(String text) =>
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.white60));
  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xff142124),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    ),
  );
}
