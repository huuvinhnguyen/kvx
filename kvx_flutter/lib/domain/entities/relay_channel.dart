class RelayChannel {
  final int index;
  final bool isOn;
  final String? label;

  const RelayChannel({
    required this.index,
    required this.isOn,
    this.label,
  });

  RelayChannel copyWith({
    int? index,
    bool? isOn,
    String? label,
  }) {
    return RelayChannel(
      index: index ?? this.index,
      isOn: isOn ?? this.isOn,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayChannel &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}
