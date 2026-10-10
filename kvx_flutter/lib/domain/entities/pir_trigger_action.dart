enum PirTriggerConfigurationMode { empty, actions, legacy, invalidLegacy }

enum PirTriggerActionOrigin { persisted, legacy }

enum PirTriggerTargetType { switchDevice, buzzer }

class PirTriggerDurationBounds {
  final int minimum;
  final int maximum;
  const PirTriggerDurationBounds(this.minimum, this.maximum);
  bool contains(int value) => value >= minimum && value <= maximum;
}

class PirTriggerTarget {
  final int id;
  final String chipId;
  final String? name;
  final PirTriggerTargetType type;
  final List<int> relayIndexes;
  final PirTriggerDurationBounds durationBounds;
  const PirTriggerTarget({
    required this.id,
    required this.chipId,
    this.name,
    required this.type,
    required this.relayIndexes,
    required this.durationBounds,
  });
  String get displayName => name?.isNotEmpty == true ? name! : chipId;
  String get typeLabel =>
      type == PirTriggerTargetType.buzzer ? 'buzzer' : 'switch';
}

class PirTriggerTargetSummary {
  final int id;
  final String chipId;
  final String? name;
  final PirTriggerTargetType type;
  const PirTriggerTargetSummary({
    required this.id,
    required this.chipId,
    this.name,
    required this.type,
  });
  String get displayName => name?.isNotEmpty == true ? name! : chipId;
  String get typeLabel =>
      type == PirTriggerTargetType.buzzer ? 'buzzer' : 'switch';
}

class PirTriggerAction {
  final int? id;
  final PirTriggerActionOrigin origin;
  final PirTriggerTargetSummary? target;
  final int relayIndex;
  final int durationMs;
  final int delayMs;
  final bool enabled;
  final int position;
  const PirTriggerAction({
    required this.id,
    required this.origin,
    required this.target,
    required this.relayIndex,
    required this.durationMs,
    required this.delayMs,
    required this.enabled,
    required this.position,
  });
}

class PirTriggerSource {
  final int id;
  final String? name;
  final String chipId;
  const PirTriggerSource(this.id, this.name, this.chipId);
}

class PirTriggerConfiguration {
  final PirTriggerConfigurationMode mode;
  final PirTriggerSource source;
  final List<PirTriggerAction> actions;
  const PirTriggerConfiguration(this.mode, this.source, this.actions);
}

class PirTriggerSnapshot {
  final PirTriggerConfiguration configuration;
  final List<PirTriggerTarget> targets;
  const PirTriggerSnapshot(this.configuration, this.targets);
}

class PirTriggerActionDraft {
  final int targetId;
  final int relayIndex;
  final int durationMs;
  final bool enabled;
  const PirTriggerActionDraft({
    required this.targetId,
    required this.relayIndex,
    required this.durationMs,
    required this.enabled,
  });
  bool isValid(List<PirTriggerTarget> targets) {
    final matches = targets.where((value) => value.id == targetId);
    if (matches.isEmpty) return false;
    final target = matches.single;
    return target.relayIndexes.contains(relayIndex) &&
        target.durationBounds.contains(durationMs);
  }
}

enum PirTriggerFailureKind {
  authentication,
  unavailable,
  rejected,
  featureDisabled,
  connection,
  invalidResponse,
  uncertainMutation,
}

class PirTriggerFailure implements Exception {
  final PirTriggerFailureKind kind;
  final String? code;
  final String message;
  const PirTriggerFailure(this.kind, this.message, {this.code});
  @override
  String toString() => message;
}
