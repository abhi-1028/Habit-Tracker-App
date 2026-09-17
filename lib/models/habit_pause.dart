class HabitPause {
  final DateTime startDate;
  final DateTime endDate;
  final String reason;

  const HabitPause({
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  // --------------------------------------------------
  // DATE CHECK
  // --------------------------------------------------

  bool containsDate(DateTime date) {
    final day = _dateOnly(date);
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    return !day.isBefore(start) &&
        !day.isAfter(end);
  }

  // --------------------------------------------------
  // ACTIVE STATUS
  // --------------------------------------------------

  bool get isActive {
    return containsDate(DateTime.now());
  }

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------

  HabitPause copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
  }) {
    return HabitPause(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
    );
  }

  // --------------------------------------------------
  // STORAGE
  // --------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
    };
  }

  // --------------------------------------------------
  // LOAD FROM STORAGE
  // --------------------------------------------------

  factory HabitPause.fromMap(
      Map<String, dynamic> map,
      ) {
    return HabitPause(
      startDate: DateTime.parse(
        map['startDate'] as String,
      ),
      endDate: DateTime.parse(
        map['endDate'] as String,
      ),
      reason:
      map['reason'] as String? ?? 'Other',
    );
  }

  // --------------------------------------------------
  // DATE HELPER
  // --------------------------------------------------

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }
}