class BuzzerDetail {
  final String id;
  final String name;
  final String chipId;
  final bool online;
  final DateTime? lastSeen;
  final int linkedPirCount;
  final DateTime? lastTriggeredAt;
  final List<BuzzerSource> sources;
  final List<BuzzerMotionEvent> events;

  BuzzerDetail({
    required this.id,
    required this.name,
    required this.chipId,
    required this.online,
    this.lastSeen,
    required this.linkedPirCount,
    this.lastTriggeredAt,
    required List<BuzzerSource> sources,
    required List<BuzzerMotionEvent> events,
  }) : sources = List.unmodifiable(sources), events = List.unmodifiable(events);
}

class BuzzerSource {
  final String id;
  final String name;
  final String chipId;
  final int relayIndex;
  final int? longlast;
  const BuzzerSource({required this.id, required this.name, required this.chipId, required this.relayIndex, this.longlast});
}

class BuzzerMotionEvent {
  final String id;
  final String eventType;
  final String pirId;
  final String sourceName;
  final String sourceChipId;
  final DateTime occurredAt;
  final int relayIndex;
  final int? longlast;
  const BuzzerMotionEvent({required this.id, required this.eventType, required this.pirId, required this.sourceName, required this.sourceChipId, required this.occurredAt, required this.relayIndex, this.longlast});
}

class BuzzerTestReceipt {
  final String message;
  final int? relayIndex;
  final int? longlast;
  const BuzzerTestReceipt({required this.message, this.relayIndex, this.longlast});
}

enum BuzzerFailureKind { authentication, unavailable, configuration, cooldown, command, invalidData, connection }

class BuzzerFailure implements Exception {
  final BuzzerFailureKind kind;
  final int retryAfterSeconds;
  const BuzzerFailure(this.kind, {this.retryAfterSeconds = 3});
  @override
  String toString() => switch (kind) {
    BuzzerFailureKind.authentication => 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại Binblog.',
    BuzzerFailureKind.unavailable => 'Chưa tải được dữ liệu mở rộng của Buzzer. Máy chủ có thể chưa hỗ trợ tính năng này hoặc tài khoản chưa có quyền truy cập.',
    BuzzerFailureKind.configuration => 'Cấu hình Buzzer chưa hợp lệ.',
    BuzzerFailureKind.cooldown => 'Vui lòng chờ $retryAfterSeconds giây trước khi test lại.',
    BuzzerFailureKind.command => 'Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại.',
    BuzzerFailureKind.invalidData => 'Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu.',
    BuzzerFailureKind.connection => 'Không tải được dữ liệu. Kiểm tra kết nối rồi thử lại.',
  };
}
