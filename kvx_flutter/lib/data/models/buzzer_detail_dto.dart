import '../../domain/entities/buzzer_detail.dart';

class BuzzerDetailDto {
  static BuzzerDetail fromJson(Map<String, dynamic> json) =>
      fromDetailJson(json);

  static BuzzerDetail fromDetailJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final value = json['buzzer'] as Map<String, dynamic>;
      if (value['device_type'] != 'buzzer') throw const FormatException();
      return BuzzerDetail(
        id: '${value['id']}',
        name: value['name'] as String,
        chipId: _requiredString(value['chip_id']),
        online: value['online'] as bool,
        lastSeen: _date(value['last_seen']),
        linkedPirCount: value['linked_pir_count'] as int,
        lastTriggeredAt: _date(value['last_triggered_at']),
        sources: const [],
        events: const [],
      );
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
  }

  static List<BuzzerSource> sourcesFromJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final values = (json['linked_pirs'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        return BuzzerSource(
          id: '${item['id']}',
          name: item['name'] as String? ?? _requiredString(item['chip_id']),
          chipId: _requiredString(item['chip_id']),
          relayIndex: _storedInteger(item['relay_index']),
          longlast: _storedInteger(item['longlast']),
          relayDisplay: _storedDisplay(item['relay_index']),
          longlastDisplay: _storedDisplay(item['longlast']),
        );
      }).toList();
      if (values.map((item) => item.id).toSet().length != values.length) {
        throw const FormatException();
      }
      return values;
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
  }

  static List<AvailableBuzzerPir> availableFromJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      return (json['available_pirs'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final linked = item['linked_buzzer'] as Map<String, dynamic>?;
        final id = item['id'];
        if (id is! int ||
            id <= 0 ||
            item['name'] != null && item['name'] is! String ||
            item['requires_confirmation'] is! bool) {
          throw const FormatException();
        }
        if (linked != null &&
            (linked['id'] is! int ||
                linked['name'] != null && linked['name'] is! String)) {
          throw const FormatException();
        }
        return AvailableBuzzerPir(
          id: '$id',
          name: item['name'] as String?,
          chipId: _requiredString(item['chip_id']),
          linkedBuzzer: linked == null
              ? null
              : LinkedBuzzer('${linked['id']}', linked['name'] as String?),
          requiresConfirmation: item['requires_confirmation'] as bool,
        );
      }).toList();
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
  }

  static List<BuzzerMotionEvent> eventsFromJson(Map<String, dynamic> json) {
    try {
      if (json['status'] != 'success') throw const FormatException();
      final values = (json['events'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final pir = item['pir'] as Map<String, dynamic>;
        return BuzzerMotionEvent(
          id: '${item['id']}',
          eventType: item['event_type'] as String,
          pirId: '${pir['id']}',
          sourceName: pir['name'] as String? ?? _requiredString(pir['chip_id']),
          sourceChipId: _requiredString(pir['chip_id']),
          occurredAt: _date(item['occurred_at'])!,
          relayIndex: _storedInteger(item['relay_index']),
          longlast: _storedInteger(item['longlast']),
          relayDisplay: _storedDisplay(item['relay_index']),
          longlastDisplay: _storedDisplay(item['longlast']),
        );
      }).toList();
      if (values.length > 20 ||
          values.map((item) => item.id).toSet().length != values.length) {
        throw const FormatException();
      }
      return values;
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
  }

  static String _requiredString(dynamic value) {
    if (value is! String || value.isEmpty) throw const FormatException();
    return value;
  }

  static String? _storedDisplay(dynamic value) =>
      value is String || value is num ? '$value' : null;

  static int? _storedInteger(dynamic value) => value is int
      ? value
      : value is String
      ? int.tryParse(value)
      : null;

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException();
    }
    return DateTime.tryParse(value) ?? (throw const FormatException());
  }
}
