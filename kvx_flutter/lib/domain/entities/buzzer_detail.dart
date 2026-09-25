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
  }) : sources = List.unmodifiable(sources),
       events = List.unmodifiable(events);
}

class BuzzerSource {
  final String id;
  final String name;
  final String chipId;
  final int? relayIndex;
  final int? longlast;
  final String? relayDisplay;
  final String? longlastDisplay;
  const BuzzerSource({
    required this.id,
    required this.name,
    required this.chipId,
    required this.relayIndex,
    this.longlast,
    this.relayDisplay,
    this.longlastDisplay,
  });
}

class BuzzerMotionEvent {
  final String id;
  final String eventType;
  final String pirId;
  final String sourceName;
  final String sourceChipId;
  final DateTime occurredAt;
  final int? relayIndex;
  final int? longlast;
  final String? relayDisplay;
  final String? longlastDisplay;
  const BuzzerMotionEvent({
    required this.id,
    required this.eventType,
    required this.pirId,
    required this.sourceName,
    required this.sourceChipId,
    required this.occurredAt,
    required this.relayIndex,
    this.longlast,
    this.relayDisplay,
    this.longlastDisplay,
  });
}

class BuzzerTestReceipt {
  final String message;
  final int? relayIndex;
  final int? longlast;
  const BuzzerTestReceipt({
    required this.message,
    this.relayIndex,
    this.longlast,
  });
}

enum BuzzerFailureKind {
  authentication,
  unavailable,
  configuration,
  cooldown,
  command,
  invalidData,
  connection,
  uncertainMutation,
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
    BuzzerFailureKind.configuration => 'Cấu hình Buzzer chưa hợp lệ.',
    BuzzerFailureKind.cooldown =>
      'Vui lòng chờ $retryAfterSeconds giây trước khi test lại.',
    BuzzerFailureKind.command =>
      'Chưa xác định được kết quả gửi lệnh. Hãy tải lại dữ liệu trước khi quyết định gửi lại.',
    BuzzerFailureKind.invalidData =>
      'Dữ liệu Buzzer không hợp lệ. Hãy tải lại dữ liệu.',
    BuzzerFailureKind.connection =>
      'Không tải được dữ liệu. Kiểm tra kết nối rồi thử lại.',
    BuzzerFailureKind.uncertainMutation =>
      'Chưa xác nhận được kết quả cập nhật cấu hình. Hãy tải lại dữ liệu trước khi chỉnh sửa tiếp.',
  };
}

class AvailableBuzzerPir {
  final String id;
  final String? name;
  final String chipId;
  final LinkedBuzzer? linkedBuzzer;
  final bool requiresConfirmation;
  const AvailableBuzzerPir({
    required this.id,
    this.name,
    required this.chipId,
    this.linkedBuzzer,
    required this.requiresConfirmation,
  });
  String get displayName => name?.isNotEmpty == true ? name! : chipId;
  String? confirmation(String currentId) {
    if (linkedBuzzer != null && linkedBuzzer!.id != currentId) {
      return 'PIR sẽ ngừng kích hoạt ${linkedBuzzer!.name ?? "Buzzer hiện tại"} và chuyển sang Buzzer này. Bạn muốn chuyển & liên kết?';
    }
    return requiresConfirmation
        ? 'Cấu hình hiện có của PIR sẽ bị thay thế bằng liên kết với Buzzer này. Bạn muốn thay thế & liên kết?'
        : null;
  }
}

class LinkedBuzzer {
  final String id;
  final String? name;
  const LinkedBuzzer(this.id, this.name);
}

class BuzzerLinkConfiguration {
  final String pirId;
  final int relayIndex;
  final int longlast;
  const BuzzerLinkConfiguration(this.pirId, this.relayIndex, this.longlast);
  bool get isValid =>
      (int.tryParse(pirId) ?? 0) > 0 &&
      relayIndex >= 0 &&
      longlast >= 100 &&
      longlast <= 10000;
}
