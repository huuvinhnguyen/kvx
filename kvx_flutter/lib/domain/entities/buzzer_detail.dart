class BuzzerDetail {
  final String id;
  final String name;
  final String chipId;
  final bool online;
  final DateTime? lastSeen;
  final String? buildVersion;
  final String? appVersion;
  final int? testDurationMs;
  final List<BuzzerSource> sources;
  final List<BuzzerMotionEvent> events;

  BuzzerDetail({
    required this.id,
    required this.name,
    required this.chipId,
    required this.online,
    this.lastSeen,
    this.buildVersion,
    this.appVersion,
    this.testDurationMs,
    required List<BuzzerSource> sources,
    required List<BuzzerMotionEvent> events,
  }) : sources = List.unmodifiable(sources),
       events = List.unmodifiable(events);

  bool get canTest =>
      testDurationMs != null &&
      testDurationMs! >= 100 &&
      testDurationMs! <= 10000;
}

class BuzzerSource {
  final String id;
  final String name;
  final String chipId;
  final int relayIndex;
  final int? durationMs;
  const BuzzerSource({
    required this.id,
    required this.name,
    required this.chipId,
    required this.relayIndex,
    this.durationMs,
  });
}

class BuzzerMotionEvent {
  final String id;
  final String sourceId;
  final String sourceName;
  final String sourceChipId;
  final DateTime occurredAt;
  final int? durationMs;
  const BuzzerMotionEvent({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.sourceChipId,
    required this.occurredAt,
    this.durationMs,
  });
}

enum BuzzerCommand { test, refresh, restart, resetWifi }

class BuzzerCommandReceipt {
  final int cooldownSeconds;
  const BuzzerCommandReceipt({this.cooldownSeconds = 0});
}

enum BuzzerFailureKind {
  authentication,
  unavailable,
  configuration,
  cooldown,
  command,
  invalidData,
  connection,
}

class BuzzerFailure implements Exception {
  final BuzzerFailureKind kind;
  final int retryAfterSeconds;
  const BuzzerFailure(this.kind, {this.retryAfterSeconds = 3});

  @override
  String toString() => switch (kind) {
    BuzzerFailureKind.authentication =>
      'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại Binblog.',
    BuzzerFailureKind.unavailable =>
      'Chưa tải được dữ liệu mở rộng của Buzzer. Máy chủ có thể chưa hỗ trợ tính năng này hoặc tài khoản chưa có quyền truy cập.',
    BuzzerFailureKind.configuration =>
      'Cấu hình Buzzer chưa hợp lệ. Thời lượng test phải từ 100 đến 10.000 ms.',
    BuzzerFailureKind.cooldown =>
      'Vui lòng chờ $retryAfterSeconds giây trước khi test lại.',
    BuzzerFailureKind.command =>
      'Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại.',
    BuzzerFailureKind.invalidData =>
      'Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu.',
    BuzzerFailureKind.connection =>
      'Không tải được dữ liệu. Kiểm tra kết nối rồi thử lại.',
  };
}
