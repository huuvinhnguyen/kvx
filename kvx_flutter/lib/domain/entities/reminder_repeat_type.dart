enum ReminderRepeatType {
  none('Không lặp lại'),
  daily('Hằng ngày'),
  weekly('Hằng tuần'),
  monthly('Hằng tháng');

  final String displayName;
  const ReminderRepeatType(this.displayName);
}
