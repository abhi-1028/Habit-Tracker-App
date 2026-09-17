import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/models/habit_completion.dart';
import 'package:habit_tracker/models/habit_pause.dart';

void main() {
  group('Habit core rules', () {
    test('pause makes a date not scheduled', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        type: HabitType.yesNo,
        pauses: [
          HabitPause(
            startDate: DateTime(2026, 8, 20),
            endDate: DateTime(2026, 8, 22),
            reason: 'Travel',
          ),
        ],
      );

      expect(habit.isScheduledForDate(DateTime(2026, 8, 19)), isTrue);
      expect(habit.isScheduledForDate(DateTime(2026, 8, 20)), isFalse);
      expect(habit.isScheduledForDate(DateTime(2026, 8, 22)), isFalse);
      expect(habit.isScheduledForDate(DateTime(2026, 8, 23)), isTrue);
    });

    test('completion lookup is date based', () {
      final habit = Habit(
        id: '1',
        name: 'Read',
        type: HabitType.yesNo,
        completions: [
          HabitCompletion(
            date: DateTime(2026, 8, 18, 21, 30),
            value: 1,
            target: 1,
            note: 'Great session',
          ),
        ],
      );

      final completion = habit.completionForDate(DateTime(2026, 8, 18, 8));

      expect(completion, isNotNull);
      expect(completion!.isCompleted, isTrue);
      expect(completion.note, 'Great session');
    });

    test('specific weekday schedules only required days', () {
      final habit = Habit(
        id: '1',
        name: 'Run',
        type: HabitType.yesNo,
        scheduleType: HabitScheduleType.specificDays,
        scheduledWeekdays: const [1, 3, 5],
      );

      expect(habit.isScheduledForDate(DateTime(2026, 8, 17)), isTrue); // Mon
      expect(habit.isScheduledForDate(DateTime(2026, 8, 18)), isFalse); // Tue
      expect(habit.isScheduledForDate(DateTime(2026, 8, 19)), isTrue); // Wed
    });
  });
}
