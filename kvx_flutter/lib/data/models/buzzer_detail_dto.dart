import '../../domain/entities/buzzer_detail.dart';

class BuzzerDetailDto {
  static BuzzerDetail fromJson(Map<String, dynamic> json) {
    try {
      final sources = (json['sources'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final index = item['relay_index'] as int;
        if (index < 0) throw const FormatException();
        return BuzzerSource(
          id: _id(item['id']),
          name: item['name'] as String,
          chipId: _id(item['chip_id']),
          relayIndex: index,
          durationMs: _duration(item['duration_ms']),
        );
      }).toList();
      final events = (json['events'] as List).map((raw) {
        final item = raw as Map<String, dynamic>;
        final sourceId = _id(item['source_id']);
        final sourceChipId = _id(item['source_chip_id']);
        if (!sources.any((s) => s.id == sourceId && s.chipId == sourceChipId)) {
          throw const FormatException();
        }
        final timestamp = item['occurred_at'] as String;
        // Timestamps must carry an offset; never interpret a server timestamp as phone-local time.
        if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(timestamp)) {
          throw const FormatException();
        }
        return BuzzerMotionEvent(
          id: _id(item['id']),
          sourceId: sourceId,
          sourceName: item['source_name'] as String,
          sourceChipId: sourceChipId,
          occurredAt: DateTime.parse(timestamp),
          durationMs: _duration(item['duration_ms']),
        );
      }).toList();
      if (events.length > 20 ||
          sources.map((s) => s.id).toSet().length != sources.length ||
          events.map((e) => e.id).toSet().length != events.length) {
        throw const FormatException();
      }
      final lastSeen = json['last_seen'] as String?;
      return BuzzerDetail(
        id: _id(json['id']),
        name: json['name'] as String,
        chipId: _id(json['chip_id']),
        online: json['online'] as bool,
        lastSeen:
            lastSeen == null ||
                !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(lastSeen)
            ? null
            : DateTime.tryParse(lastSeen),
        buildVersion: json['build_version'] as String?,
        appVersion: json['app_version'] as String?,
        testDurationMs: json['test_duration_ms'] as int?,
        sources: sources,
        events: events,
      );
    } catch (_) {
      throw const BuzzerFailure(BuzzerFailureKind.invalidData);
    }
  }

  static String _id(dynamic value) {
    if (value is! String || value.isEmpty) throw const FormatException();
    return value;
  }

  static int? _duration(dynamic value) {
    if (value == null) return null;
    if (value is! int || value < 0) throw const FormatException();
    return value;
  }
}
