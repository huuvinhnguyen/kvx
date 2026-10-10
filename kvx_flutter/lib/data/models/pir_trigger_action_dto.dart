import '../../domain/entities/pir_trigger_action.dart';

Never _invalid() => throw const PirTriggerFailure(
  PirTriggerFailureKind.invalidResponse,
  'Máy chủ trả về cấu hình hành động không hợp lệ.',
);
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : _invalid();
int _int(Object? value) => value is int ? value : _invalid();
String _string(Object? value) => value is String ? value : _invalid();
bool _bool(Object? value) => value is bool ? value : _invalid();

PirTriggerTargetType _type(Object? value) => switch (value) {
  'switch' => PirTriggerTargetType.switchDevice,
  'buzzer' => PirTriggerTargetType.buzzer,
  _ => _invalid(),
};

PirTriggerAction actionFromJson(Object? value) {
  final json = _map(value);
  final origin = switch (json['origin']) {
    'persisted' => PirTriggerActionOrigin.persisted,
    'legacy' => PirTriggerActionOrigin.legacy,
    _ => _invalid(),
  };
  final id = json['id'];
  if (origin == PirTriggerActionOrigin.persisted && (id is! int || id <= 0)) {
    _invalid();
  }
  if (origin == PirTriggerActionOrigin.legacy && id != null) _invalid();
  if (json['action_type'] != 'relay_pulse') _invalid();
  final relay = _int(json['relay_index']);
  final duration = _int(json['duration_ms']);
  final delay = _int(json['delay_ms']);
  final position = _int(json['position']);
  if (relay < 0 || duration <= 0 || delay < 0 || position < 0) _invalid();
  final targetJson = json['target'];
  PirTriggerTargetSummary? target;
  if (targetJson != null) {
    final row = _map(targetJson);
    final targetId = _int(row['id']);
    final chip = _string(row['chip_id']);
    if (targetId <= 0 || chip.isEmpty) _invalid();
    target = PirTriggerTargetSummary(
      id: targetId,
      chipId: chip,
      name: row['name'] as String?,
      type: _type(row['device_type']),
    );
  }
  return PirTriggerAction(
    id: id as int?,
    origin: origin,
    target: target,
    relayIndex: relay,
    durationMs: duration,
    delayMs: delay,
    enabled: _bool(json['enabled']),
    position: position,
  );
}

PirTriggerConfiguration configurationFromJson(Map<String, dynamic> json) {
  if (json['status'] != 'success') _invalid();
  final mode = switch (json['configuration_mode']) {
    'none' || 'empty' => PirTriggerConfigurationMode.empty,
    'actions' => PirTriggerConfigurationMode.actions,
    'legacy' => PirTriggerConfigurationMode.legacy,
    'invalid_legacy' => PirTriggerConfigurationMode.invalidLegacy,
    _ => _invalid(),
  };
  final source = _map(json['source_device']);
  final sourceId = _int(source['id']);
  final chip = _string(source['chip_id']);
  if (sourceId <= 0 || chip.isEmpty) _invalid();
  final rawActions = json['actions'];
  if (rawActions is! List) _invalid();
  final actions = rawActions.map(actionFromJson).toList(growable: false);
  if ((mode == PirTriggerConfigurationMode.empty ||
          mode == PirTriggerConfigurationMode.invalidLegacy) &&
      actions.isNotEmpty) {
    _invalid();
  }
  if (mode == PirTriggerConfigurationMode.legacy &&
      (actions.length != 1 ||
          actions.single.origin != PirTriggerActionOrigin.legacy)) {
    _invalid();
  }
  if (mode == PirTriggerConfigurationMode.actions &&
      actions.any(
        (value) =>
            value.origin != PirTriggerActionOrigin.persisted ||
            value.id == null,
      )) {
    _invalid();
  }
  return PirTriggerConfiguration(
    mode,
    PirTriggerSource(sourceId, source['name'] as String?, chip),
    actions,
  );
}

List<PirTriggerTarget> targetsFromJson(Map<String, dynamic> json) {
  if (json['status'] != 'success' || json['targets'] is! List) _invalid();
  return (json['targets'] as List)
      .map((value) {
        final row = _map(value);
        final bounds = _map(row['duration_ms']);
        final id = _int(row['id']);
        final chip = _string(row['chip_id']);
        final relays = row['relay_indexes'];
        final minimum = _int(bounds['minimum']);
        final maximum = _int(bounds['maximum']);
        if (id <= 0 ||
            chip.isEmpty ||
            relays is! List ||
            relays.isEmpty ||
            relays.any((item) => item is! int || item < 0) ||
            relays.toSet().length != relays.length ||
            minimum <= 0 ||
            maximum < minimum) {
          _invalid();
        }
        return PirTriggerTarget(
          id: id,
          chipId: chip,
          name: row['name'] as String?,
          type: _type(row['device_type']),
          relayIndexes: relays.cast<int>(),
          durationBounds: PirTriggerDurationBounds(minimum, maximum),
        );
      })
      .toList(growable: false);
}
