import '../../domain/entities/switch_detail.dart';

class SwitchDto {
  static Never invalid() =>
      throw const SwitchFailure(SwitchFailureKind.invalidData);
  static void require(bool value) {
    if (!value) invalid();
  }

  static bool id(Object? value) =>
      value is String &&
      RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value) &&
      BigInt.parse(value) <= BigInt.parse('9223372036854775807');
  static void success(Map<String, dynamic> json) =>
      require(json['status'] == 'success');
  static SwitchDetail detail(Map<String, dynamic> json) {
    success(json);
    final d = json['switch'] as Map<String, dynamic>;
    require(
      id(d['id']) &&
          d['device_type'] == 'switch' &&
          d['timezone'] == 'Asia/Ho_Chi_Minh' &&
          d.containsKey('online') &&
          d['online'] == null &&
          d['physical_state_verified'] == false &&
          d['state_source'] == 'server_snapshot' &&
          d.containsKey('last_seen') &&
          (d['last_seen'] == null || d['last_seen'] is String),
    );
    final seen = d['last_seen'] as String?;
    if (seen != null) require(switchTimestamp(seen) != null);
    final caps = d['capabilities'] as Map<String, dynamic>;
    for (final key in [
      'manual_switch',
      'pulse',
      'refresh',
      'statistics',
      'reminders',
    ]) {
      require(caps[key] is bool);
    }
    final limits = d['limits'] as Map<String, dynamic>;
    require(
      limits['duration_min_ms'] == 1000 &&
          limits['duration_max_ms'] == 86400000,
    );
    final relays = d['relays'] as List;
    require(relays.length <= 32);
    final mapped = <SwitchRelay>[];
    for (var i = 0; i < relays.length; i++) {
      final r = relays[i] as Map<String, dynamic>;
      require(
        r['index'] is int &&
            r['index'] == i &&
            r.containsKey('switch_value') &&
            (r['switch_value'] == null ||
                (r['switch_value'] is int &&
                    [0, 1].contains(r['switch_value']))) &&
            r.containsKey('duration_ms') &&
            (r['duration_ms'] == null || r['duration_ms'] is int) &&
            r.containsKey('reminders_active') &&
            (r['reminders_active'] == null || r['reminders_active'] is bool),
      );
      mapped.add(
        SwitchRelay(
          i,
          r['switch_value'] as int?,
          r['duration_ms'] as int?,
          r['reminders_active'] as bool?,
        ),
      );
    }
    return SwitchDetail(
      id: d['id'] as String,
      name: d['name'] as String,
      lastSeen: seen == null ? null : DateTime.parse(seen),
      manualSwitch: caps['manual_switch'] as bool,
      pulse: caps['pulse'] as bool,
      refresh: caps['refresh'] as bool,
      statistics: caps['statistics'] as bool,
      relays: List.unmodifiable(mapped),
    );
  }

  static SwitchReminderPage reminders(
    Map<String, dynamic> json,
    String device,
    int relay,
    String? afterId,
  ) {
    success(json);
    require(json.containsKey('next_after_id'));
    final next = json['next_after_id'];
    require(next == null || id(next));
    final rows = json['reminders'] as List;
    require(rows.length <= 100);
    var previous = afterId == null ? BigInt.zero : BigInt.parse(afterId);
    final result = <SwitchReminder>[];
    for (final item in rows) {
      final r = item as Map<String, dynamic>;
      require(
        id(r['id']) &&
            r['device_id'] == device &&
            r['relay_index'] is int &&
            r['relay_index'] == relay &&
            r.containsKey('duration_ms') &&
            (r['duration_ms'] == null || r['duration_ms'] is int) &&
            r['enabled'] is bool &&
            r['configuration_valid'] is bool &&
            r['repeat_type'] is String &&
            r.containsKey('start_time') &&
            (r['start_time'] == null || r['start_time'] is String),
      );
      final current = BigInt.parse(r['id'] as String);
      require(current > previous);
      previous = current;
      // Keep invalid legacy configuration visible, never invent a valid schedule.
      result.add(
        SwitchReminder(
          r['id'] as String,
          device,
          relay,
          r['start_time'] as String?,
          r['duration_ms'] as int?,
          r['repeat_type'] as String,
          r['enabled'] as bool,
          r['configuration_valid'] as bool,
        ),
      );
    }
    require(next == null || (result.isNotEmpty && next == result.last.id));
    return SwitchReminderPage(List.unmodifiable(result), next as String?);
  }

  static SwitchStatistics statistics(Map<String, dynamic> j) {
    success(j);
    require(
      j['timezone'] == 'Asia/Ho_Chi_Minh' &&
          j['metric'] == 'log_records' &&
          j.containsKey('physical_runtime_seconds') &&
          j['physical_runtime_seconds'] == null &&
          j['physical_runtime_verified'] == false &&
          j['total_records'] is int &&
          (j['total_records'] as int) >= 0,
    );
    final from = DateTime.parse('${j['from']}T00:00:00Z'),
        to = DateTime.parse('${j['to']}T00:00:00Z');
    require(
      from.toIso8601String().substring(0, 10) == j['from'] &&
          to.toIso8601String().substring(0, 10) == j['to'],
    );
    final rows = j['days'] as List;
    final length = to.difference(from).inDays + 1;
    require(length >= 1 && length <= 31 && rows.length == length);
    final days = <SwitchLogDay>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i] as Map<String, dynamic>;
      require(
        r['date'] ==
                from
                    .add(Duration(days: i))
                    .toIso8601String()
                    .substring(0, 10) &&
            r['count'] is int &&
            (r['count'] as int) >= 0,
      );
      days.add(SwitchLogDay(r['date'] as String, r['count'] as int));
    }
    require(days.fold<int>(0, (n, d) => n + d.count) == j['total_records']);
    return SwitchStatistics(
      j['from'] as String,
      j['to'] as String,
      j['total_records'] as int,
      List.unmodifiable(days),
    );
  }
}
