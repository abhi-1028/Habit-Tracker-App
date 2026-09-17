class HabitCompletion {
  final DateTime date;
  final int value;
  final int target;
  final String? note;
  final DateTime? completedAt;

  const HabitCompletion({
    required this.date,
    required this.value,
    required this.target,
    this.note,
    this.completedAt,
  });

  bool get isCompleted => value >= target;

  bool get canUndo {
    if (!isCompleted || completedAt == null) return false;
    return DateTime.now().difference(completedAt!).inMinutes < 10;
  }

  HabitCompletion copyWith({
    DateTime? date,
    int? value,
    int? target,
    String? note,
    bool clearNote = false,
    DateTime? completedAt,
  }) {
    return HabitCompletion(
      date: date ?? this.date,
      value: value ?? this.value,
      target: target ?? this.target,
      note: clearNote ? null : (note ?? this.note),
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
