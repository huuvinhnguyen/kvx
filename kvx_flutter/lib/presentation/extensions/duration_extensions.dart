extension DurationExtensions on Duration {
  /// Converts duration to Vietnamese display format
  String toVietnamese() {
    if (inDays > 0) {
      return '$inDays ngày';
    } else if (inHours > 0) {
      return '$inHours giờ';
    } else if (inMinutes > 0) {
      return '$inMinutes phút';
    } else {
      return '$inSeconds giây';
    }
  }

  /// Converts duration to a more readable Vietnamese format with multiple units
  String toDetailedVietnamese() {
    final days = inDays;
    final hours = inHours % 24;
    final minutes = inMinutes % 60;
    final seconds = inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days ngày');
    if (hours > 0) parts.add('$hours giờ');
    if (minutes > 0) parts.add('$minutes phút');
    if (seconds > 0 && days == 0) parts.add('$seconds giây');

    return parts.isEmpty ? '0 giây' : parts.join(' ');
  }
}
