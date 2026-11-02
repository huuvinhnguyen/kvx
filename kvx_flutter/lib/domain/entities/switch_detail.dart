class SwitchRelay {
  final int index;
  final int? switchValue;
  final int? durationMs;
  final bool? remindersActive;
  const SwitchRelay(
    this.index,
    this.switchValue,
    this.durationMs,
    this.remindersActive,
  );
}

class SwitchDetail {
  final String id, name;
  final DateTime? lastSeen;
  final bool manualSwitch, pulse, refresh, statistics;
  final List<SwitchRelay> relays;
  const SwitchDetail({
    required this.id,
    required this.name,
    required this.lastSeen,
    required this.manualSwitch,
    required this.pulse,
    required this.refresh,
    required this.statistics,
    required this.relays,
  });
}

class SwitchReminder {
  final String id, deviceId, repeatType;
  final String? startTime;
  final int relayIndex;
  final int? durationMs;
  final bool enabled, configurationValid;
  const SwitchReminder(
    this.id,
    this.deviceId,
    this.relayIndex,
    this.startTime,
    this.durationMs,
    this.repeatType,
    this.enabled,
    this.configurationValid,
  );
}

class SwitchReminderPage {
  final List<SwitchReminder> reminders;
  final String? nextAfterId;
  const SwitchReminderPage(this.reminders, this.nextAfterId);
}

class SwitchLogDay {
  final String date;
  final int count;
  const SwitchLogDay(this.date, this.count);
}

class SwitchStatistics {
  final String from, to;
  final int totalRecords;
  final List<SwitchLogDay> days;
  const SwitchStatistics(this.from, this.to, this.totalRecords, this.days);
}

enum SwitchFailureKind {
  authentication,
  unavailable,
  validation,
  connection,
  invalidData,
  uncertain,
}

class SwitchFailure implements Exception {
  final SwitchFailureKind kind;
  const SwitchFailure(this.kind);
  @override
  String toString() => switch (kind) {
    SwitchFailureKind.authentication => 'Phiên đăng nhập đã hết hạn.',
    SwitchFailureKind.unavailable => 'Switch hoặc tính năng chưa khả dụng.',
    SwitchFailureKind.validation => 'Cấu hình hoặc dữ liệu không hợp lệ.',
    SwitchFailureKind.connection => 'Không tải được dữ liệu. Hãy tải lại.',
    SwitchFailureKind.invalidData => 'Máy chủ trả về dữ liệu không hợp lệ.',
    SwitchFailureKind.uncertain =>
      'Chưa xác định lệnh đã được gửi hay chưa. Không tự gửi lại. Hãy kiểm tra thiết bị.',
  };
}

int? switchDurationMs(String text, {required bool minutes}) {
  if (!RegExp(r'^[0-9]+$').hasMatch(text.trim())) return null;
  final amount = int.tryParse(text.trim());
  final max = minutes ? 1440 : 86400;
  if (amount == null || amount < 1 || amount > max) return null;
  return amount * (minutes ? 60000 : 1000);
}

DateTime? switchTimestamp(String? raw) {
  if (raw == null ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$',
      ).hasMatch(raw)) {
    return null;
  }
  final year = int.parse(raw.substring(0, 4)),
      month = int.parse(raw.substring(5, 7)),
      day = int.parse(raw.substring(8, 10));
  final date = DateTime.utc(year, month, day);
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(raw.substring(11, 13)) > 23 ||
      int.parse(raw.substring(14, 16)) > 59 ||
      int.parse(raw.substring(17, 19)) > 59) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}
