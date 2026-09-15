class PirStatistics {
  final String date;
  final List<int> values;
  final int total;
  final List<PirMotionEvent>? recentEvents;
  const PirStatistics(this.date, this.values, this.total, {this.recentEvents});

  factory PirStatistics.fromJson(Map<String, dynamic> json) {
    final values = (json['values'] as List).cast<int>();
    final total = json['total'] as int;
    if (values.length != 24 ||
        values.any((v) => v < 0) ||
        values.fold(0, (int a, b) => a + b) != total) {
      throw const FormatException('Dữ liệu thống kê không hợp lệ.');
    }
    return PirStatistics(
      json['date'] as String,
      values,
      total,
      recentEvents: (json['recent_events'] as List?)
          ?.take(20)
          .map((v) => PirMotionEvent.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PirDay {
  final String date;
  final int count;
  const PirDay(this.date, this.count);
  int get level => count == 0
      ? 0
      : count <= 3
      ? 1
      : count <= 8
      ? 2
      : count <= 15
      ? 3
      : 4;
  factory PirDay.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String;
    final count = json['count'] as int;
    if (DateTime.tryParse(date) == null || count < 0) {
      throw const FormatException('Dữ liệu mật độ không hợp lệ.');
    }
    return PirDay(date, count);
  }
}

// Date-only values represent the server's Asia/Ho_Chi_Minh calendar.
DateTime pirToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(now.year, now.month, now.day);
}

String pirDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class PirMotionEvent {
  final int id;
  final DateTime occurredAt;
  const PirMotionEvent(this.id, this.occurredAt);
  factory PirMotionEvent.fromJson(Map<String, dynamic> json) => PirMotionEvent(
    json['id'] as int,
    DateTime.parse(json['occurred_at'] as String),
  );
  String get displayTime {
    final date = occurredAt.toUtc().add(const Duration(hours: 7));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}
