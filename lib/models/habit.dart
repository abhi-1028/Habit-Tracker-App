import 'habit_completion.dart';
import 'habit_pause.dart';

enum HabitType { yesNo, measurable }

enum HabitScheduleType { daily, specificDays }

class HabitSchedulePeriod {
  final DateTime startDate;
  final HabitScheduleType scheduleType;
  final List<int> scheduledWeekdays;

  const HabitSchedulePeriod({
    required this.startDate,
    required this.scheduleType,
    this.scheduledWeekdays = const [],
  });

  bool isScheduled(DateTime date) {
    if (scheduleType == HabitScheduleType.daily) return true;
    return scheduledWeekdays.contains(date.weekday);
  }

  Map<String, dynamic> toMap() => {
    'startDate': startDate.toIso8601String(),
    'scheduleType': scheduleType.name,
    'scheduledWeekdays': List<int>.from(scheduledWeekdays),
  };

  factory HabitSchedulePeriod.fromMap(Map<String, dynamic> map) {
    final days = (map['scheduledWeekdays'] as List?)
        ?.whereType<num>()
        .map((e) => e.toInt())
        .where((e) => e >= 1 && e <= 7)
        .toList() ?? <int>[];
    return HabitSchedulePeriod(
      startDate: DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.now(),
      scheduleType: HabitScheduleType.values.firstWhere(
        (e) => e.name == map['scheduleType'],
        orElse: () => HabitScheduleType.daily,
      ),
      scheduledWeekdays: days,
    );
  }
}

enum HabitDayStatus {
  beforeCreation,
  future,
  paused,
  notScheduled,
  pending,
  completed,
  missed,
}

class Habit {
  final String id;
  final String name;
  final HabitType type;
  final int target;
  final String unit;
  final String icon;
  final int colorValue;
  final HabitScheduleType scheduleType;
  final List<int> scheduledWeekdays;
  final int todayProgress;
  final List<HabitCompletion> completions;
  final List<HabitPause> pauses;
  final DateTime? createdAt;
  final List<HabitSchedulePeriod> scheduleHistory;
  final bool isArchived;

  const Habit({
    required this.id,
    required this.name,
    required this.type,
    this.target = 1,
    this.unit = '',
    this.icon = 'check',
    this.colorValue = 0xFF27E7FF,
    this.scheduleType = HabitScheduleType.daily,
    this.scheduledWeekdays = const [],
    this.todayProgress = 0,
    this.completions = const [],
    this.pauses = const [],
    this.createdAt,
    this.scheduleHistory = const [],
    this.isArchived = false,
  });

  DateTime get creationDate {
    if (createdAt != null) return _dateOnly(createdAt!);
    final millis = int.tryParse(id);
    if (millis != null) {
      return _dateOnly(DateTime.fromMillisecondsSinceEpoch(millis));
    }
    return DateTime(1970, 1, 1);
  }

  bool get isCompleted => todayProgress >= target;

  bool isPausedOnDate(DateTime date) =>
      pauses.any((pause) => pause.containsDate(date));

  HabitPause? pauseForDate(DateTime date) {
    for (final pause in pauses) {
      if (pause.containsDate(date)) return pause;
    }
    return null;
  }

  bool get isPaused => isPausedOnDate(DateTime.now());

  HabitPause? get activePause {
    for (final pause in pauses) {
      if (pause.isActive) return pause;
    }
    return null;
  }

  HabitSchedulePeriod _schedulePeriodForDate(DateTime date) {
    if (scheduleHistory.isEmpty) {
      return HabitSchedulePeriod(
        startDate: creationDate,
        scheduleType: scheduleType,
        scheduledWeekdays: scheduledWeekdays,
      );
    }

    final periods = [...scheduleHistory]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    HabitSchedulePeriod selected = periods.first;
    for (final period in periods) {
      if (!_dateOnly(period.startDate).isAfter(_dateOnly(date))) {
        selected = period;
      } else {
        break;
      }
    }
    return selected;
  }

  bool isNormallyScheduledForDate(DateTime date) {
    if (_dateOnly(date).isBefore(creationDate)) return false;
    return _schedulePeriodForDate(date).isScheduled(date);
  }

  bool isScheduledForDate(DateTime date) {
    if (!isNormallyScheduledForDate(date)) return false;
    return !isPausedOnDate(date);
  }

  HabitCompletion? completionForDate(DateTime date) {
    for (final completion in completions) {
      if (_isSameDay(completion.date, date)) return completion;
    }
    return null;
  }

  HabitDayStatus statusForDate(DateTime date) {
    final day = _dateOnly(date);
    final today = _dateOnly(DateTime.now());

    if (day.isBefore(creationDate)) return HabitDayStatus.beforeCreation;
    if (isPausedOnDate(day)) return HabitDayStatus.paused;
    if (day.isAfter(today)) {
      return isNormallyScheduledForDate(day)
          ? HabitDayStatus.future
          : HabitDayStatus.notScheduled;
    }
    if (!isNormallyScheduledForDate(day)) return HabitDayStatus.notScheduled;

    final completion = completionForDate(day);
    if (completion?.isCompleted ?? false) return HabitDayStatus.completed;
    if (day.isAtSameMomentAs(today)) return HabitDayStatus.pending;
    return HabitDayStatus.missed;
  }

  int get currentStreak {
    final today = _dateOnly(DateTime.now());
    DateTime cursor = today;
    if (statusForDate(cursor) == HabitDayStatus.pending) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (true) {
      final status = statusForDate(cursor);
      if (status == HabitDayStatus.completed) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (status == HabitDayStatus.notScheduled ||
          status == HabitDayStatus.paused) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  int get bestStreak {
    final dates = completions
        .where((c) => c.isCompleted)
        .map((c) => _dateOnly(c.date))
        .where((d) => !d.isBefore(creationDate))
        .toSet()
        .toList()
      ..sort();

    if (dates.isEmpty) return 0;
    int best = 1;
    int current = 1;

    for (var i = 1; i < dates.length; i++) {
      var cursor = dates[i - 1].add(const Duration(days: 1));
      bool valid = true;
      while (cursor.isBefore(dates[i])) {
        final status = statusForDate(cursor);
        if (status != HabitDayStatus.notScheduled &&
            status != HabitDayStatus.paused) {
          valid = false;
          break;
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      if (valid) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
    }
    return best;
  }

  Habit copyWith({
    String? id,
    String? name,
    HabitType? type,
    int? target,
    String? unit,
    String? icon,
    int? colorValue,
    HabitScheduleType? scheduleType,
    List<int>? scheduledWeekdays,
    int? todayProgress,
    List<HabitCompletion>? completions,
    List<HabitPause>? pauses,
    DateTime? createdAt,
    List<HabitSchedulePeriod>? scheduleHistory,
    bool? isArchived,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
      todayProgress: todayProgress ?? this.todayProgress,
      completions: completions ?? this.completions,
      pauses: pauses ?? this.pauses,
      createdAt: createdAt ?? this.createdAt,
      scheduleHistory: scheduleHistory ?? this.scheduleHistory,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
