import '../../domain/entities/buzzer_detail.dart';

class BuzzerDetailDto {
  static BuzzerDetail fromJson(Map<String, dynamic> json) => fromDetailJson(json);

  static BuzzerDetail fromDetailJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final value = json['buzzer'] as Map<String, dynamic>;
      if (value['device_type'] != 'buzzer') throw const FormatException();
      return BuzzerDetail(
        id: '${value['id']}', name: value['name'] as String,
        chipId: _requiredString(value['chip_id']), online: value['online'] as bool,
        lastSeen: _date(value['last_seen']), linkedPirCount: value['linked_pir_count'] as int,
        lastTriggeredAt: _date(value['last_triggered_at']), sources: const [], events: const [],
      );
    } catch (_) { throw const BuzzerFailure(BuzzerFailureKind.invalidData); }
  }

  static List<BuzzerSource> sourcesFromJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final values = (json['linked_pirs'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        return BuzzerSource(id: '${item['id']}', name: item['name'] as String,
          chipId: _requiredString(item['chip_id']), relayIndex: _nonNegative(item['relay_index']), longlast: _duration(item['longlast']));
      }).toList();
      if (values.map((item) => item.id).toSet().length != values.length) throw const FormatException();
      return values;
    } catch (_) { throw const BuzzerFailure(BuzzerFailureKind.invalidData); }
  }

  static List<BuzzerMotionEvent> eventsFromJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final values = (json['events'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final pir = item['pir'] as Map<String, dynamic>;
        return BuzzerMotionEvent(id: '${item['id']}', eventType: item['event_type'] as String,
          pirId: '${pir['id']}', sourceName: pir['name'] as String,
          sourceChipId: _requiredString(pir['chip_id']), occurredAt: _date(item['occurred_at'])!,
          relayIndex: _nonNegative(item['relay_index']), longlast: _duration(item['longlast']));
      }).toList();
      if (values.length > 20 || values.map((item) => item.id).toSet().length != values.length) throw const FormatException();
      return values;
    } catch (_) { throw const BuzzerFailure(BuzzerFailureKind.invalidData); }
  }

  static String _requiredString(dynamic value) { if (value is! String || value.isEmpty) throw const FormatException(); return value; }
  static int _nonNegative(dynamic value) { if (value is! int || value < 0) throw const FormatException(); return value; }
  static int? _duration(dynamic value) { if (value == null) return null; return _nonNegative(value); }
  static DateTime? _date(dynamic value) { if (value == null) return null; if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) throw const FormatException(); return DateTime.tryParse(value); }
}
