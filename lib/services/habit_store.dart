import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_pause.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';

class HabitStore extends ChangeNotifier {
  HabitStore._();

  static final HabitStore instance = HabitStore._();

  final List<Habit> _habits = [];

  List<Habit> get habits => List.unmodifiable(_habits);

  // --------------------------------------------------
  // LOAD SAVED HABITS
  // --------------------------------------------------

  Future<void> loadSavedHabits() async {
    final savedHabits = await LocalStorageService.loadHabitsAsync();

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    _habits
      ..clear()
      ..addAll(
        savedHabits.map((habit) {
          final isScheduledToday =
          habit.isScheduledForDate(todayDate);

          final completionToday = isScheduledToday
              ? habit.completionForDate(todayDate)
              : null;

          return habit.copyWith(
            todayProgress: completionToday?.value ?? 0,
          );
        }),
      );

    notifyListeners();
  }

  // --------------------------------------------------
  // ADD HABIT
  // --------------------------------------------------

  Habit _normalizeSchedule(Habit habit) {
    final days = habit.scheduledWeekdays.toSet().toList()..sort();
    if (days.length == 7) {
      return habit.copyWith(scheduleType: HabitScheduleType.daily, scheduledWeekdays: const []);
    }
    return habit.copyWith(scheduledWeekdays: days);
  }

  Future<bool> addHabit(Habit habit) async {
    habit = _normalizeSchedule(habit);
    final newName = habit.name.trim().toLowerCase();

    final alreadyExists = _habits.any(
          (existingHabit) =>
      existingHabit.name.trim().toLowerCase() == newName,
    );

    if (alreadyExists) {
      return false;
    }

    final created = habit.createdAt ?? DateTime.now();
    final history = habit.scheduleHistory.isEmpty
        ? [HabitSchedulePeriod(
            startDate: created,
            scheduleType: habit.scheduleType,
            scheduledWeekdays: habit.scheduledWeekdays,
          )]
        : habit.scheduleHistory;
    _habits.add(habit.copyWith(
      createdAt: created,
      scheduleHistory: history,
    ));

    notifyListeners();

    await _save();
    if (LocalStorageService.loadNotificationsEnabled()) {
      await NotificationService.scheduleHabitReminders(_habits);
      await NotificationService.showActivityNotification(title: '✨ Habit created', body: '“${habit.name}” is now part of your routine.');
    }

    return true;
  }

  // --------------------------------------------------
  // UPDATE HABIT
  // --------------------------------------------------

  Future<bool> updateHabit(Habit updatedHabit) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == updatedHabit.id,
    );

    if (index == -1) {
      return false;
    }

    final newName = updatedHabit.name.trim().toLowerCase();

    final alreadyExists = _habits.any(
          (existingHabit) =>
      existingHabit.id != updatedHabit.id &&
          existingHabit.name.trim().toLowerCase() == newName,
    );

    if (alreadyExists) {
      return false;
    }

    final oldHabit = _habits[index];

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final isScheduledToday =
    updatedHabit.isScheduledForDate(todayDate);

    int todayProgress = 0;

    if (isScheduledToday) {
      final todayCompletion =
      oldHabit.completionForDate(todayDate);

      todayProgress = todayCompletion?.value ?? 0;
    }

    // Preserve completion history AND pause history.
    var scheduleHistory = List<HabitSchedulePeriod>.from(oldHabit.scheduleHistory);
    if (scheduleHistory.isEmpty) {
      scheduleHistory.add(HabitSchedulePeriod(
        startDate: oldHabit.creationDate,
        scheduleType: oldHabit.scheduleType,
        scheduledWeekdays: oldHabit.scheduledWeekdays,
      ));
    }
    final scheduleChanged = oldHabit.scheduleType != updatedHabit.scheduleType ||
        !_sameDays(oldHabit.scheduledWeekdays, updatedHabit.scheduledWeekdays);
    if (scheduleChanged) {
      final todayOnly = _dateOnly(DateTime.now());
      final last = scheduleHistory.isNotEmpty ? scheduleHistory.last : null;
      if (last == null || _dateOnly(last.startDate) != todayOnly) {
        scheduleHistory.add(HabitSchedulePeriod(
          startDate: todayOnly,
          scheduleType: updatedHabit.scheduleType,
          scheduledWeekdays: updatedHabit.scheduledWeekdays,
        ));
      } else {
        scheduleHistory[scheduleHistory.length - 1] = HabitSchedulePeriod(
          startDate: todayOnly,
          scheduleType: updatedHabit.scheduleType,
          scheduledWeekdays: updatedHabit.scheduledWeekdays,
        );
      }
    }

    final updatedHabitWithProgress = updatedHabit.copyWith(
      todayProgress: todayProgress,
      completions: oldHabit.completions,
      pauses: oldHabit.pauses,
      createdAt: oldHabit.createdAt ?? oldHabit.creationDate,
      scheduleHistory: scheduleHistory,
      isArchived: oldHabit.isArchived,
    );

    _habits[index] = updatedHabitWithProgress;

    notifyListeners();

    await _save();
    if (LocalStorageService.loadNotificationsEnabled()) {
      await NotificationService.scheduleHabitReminders(_habits);
      await NotificationService.showActivityNotification(title: '✏️ Habit updated', body: '“${updatedHabit.name}” was updated successfully.');
    }

    return true;
  }

  // --------------------------------------------------
  // ARCHIVE / RESTORE
  // --------------------------------------------------

  Future<void> setArchived(String habitId, bool archived) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return;
    _habits[index] = _habits[index].copyWith(isArchived: archived);
    notifyListeners();
    await _save();
  }

  // --------------------------------------------------
  // DELETE HABIT
  // --------------------------------------------------

  Future<void> removeHabit(String habitId) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) return;
    final removedName = _habits[index].name;
    _habits.removeAt(index);

    notifyListeners();

    await _save();
    if (LocalStorageService.loadNotificationsEnabled()) {
      await NotificationService.scheduleHabitReminders(_habits);
      await NotificationService.showActivityNotification(title: '🗑️ Habit deleted', body: '“$removedName” was removed from your routines.');
    }
  }

  // --------------------------------------------------
  // PAUSE HABIT
  // --------------------------------------------------

  /// Adds a new pause period to a habit.
  ///
  /// The complete pause history is preserved.
  Future<bool> pauseHabit({
    required String habitId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (index == -1) {
      return false;
    }

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    // End date cannot be before start date.
    if (end.isBefore(start)) {
      return false;
    }

    final habit = _habits[index];

    // Don't allow overlapping pause periods.
    final overlapsExistingPause = habit.pauses.any(
          (pause) {
        final existingStart = _dateOnly(
          pause.startDate,
        );

        final existingEnd = _dateOnly(
          pause.endDate,
        );

        return !end.isBefore(existingStart) &&
            !start.isAfter(existingEnd);
      },
    );

    if (overlapsExistingPause) {
      return false;
    }

    final pause = HabitPause(
      startDate: start,
      endDate: end,
      reason: reason.trim().isEmpty
          ? 'Other'
          : reason.trim(),
    );

    final updatedPauses =
    List<HabitPause>.from(habit.pauses)
      ..add(pause);

    // Keep today's progress at zero while paused.
    final today = _dateOnly(DateTime.now());

    final todayProgress =
    pause.containsDate(today)
        ? 0
        : habit.todayProgress;

    _habits[index] = habit.copyWith(
      pauses: updatedPauses,
      todayProgress: todayProgress,
    );

    notifyListeners();

    await _save();

    return true;
  }

  // --------------------------------------------------
  // RESUME HABIT EARLY
  // --------------------------------------------------

  /// Ends the currently active pause today.
  ///
  /// The original pause history is preserved.
  Future<bool> resumeHabit(String habitId) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (index == -1) {
      return false;
    }

    final habit = _habits[index];

    final activePause = habit.activePause;

    if (activePause == null) {
      return false;
    }

    final today = _dateOnly(DateTime.now());

    final updatedPauses =
    List<HabitPause>.from(habit.pauses);

    final pauseIndex = updatedPauses.indexOf(
      activePause,
    );

    if (pauseIndex == -1) {
      return false;
    }

    // Resume today by ending the pause yesterday.
    //
    // Example:
    // Pause: Aug 20 → Aug 27
    // Resume: Aug 24
    //
    // Stored pause becomes:
    // Aug 20 → Aug 23
    final newEndDate =
    today.subtract(const Duration(days: 1));

    if (newEndDate.isBefore(
      _dateOnly(activePause.startDate),
    )) {
      // The pause started today, so remove it entirely.
      updatedPauses.removeAt(pauseIndex);
    } else {
      updatedPauses[pauseIndex] =
          activePause.copyWith(
            endDate: newEndDate,
          );
    }

    _habits[index] = habit.copyWith(
      pauses: updatedPauses,
      todayProgress: 0,
    );

    notifyListeners();

    await _save();

    return true;
  }

  // --------------------------------------------------
  // REMOVE PAUSE
  // --------------------------------------------------

  /// Removes a specific pause period.
  ///
  /// This is useful for future pause-history management UI.
  Future<bool> removePause({
    required String habitId,
    required HabitPause pause,
  }) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (index == -1) {
      return false;
    }

    final habit = _habits[index];

    final updatedPauses =
    List<HabitPause>.from(habit.pauses);

    final removed = updatedPauses.remove(pause);

    if (!removed) {
      return false;
    }

    _habits[index] = habit.copyWith(
      pauses: updatedPauses,
    );

    notifyListeners();

    await _save();

    return true;
  }

  // --------------------------------------------------
  // INCREASE PROGRESS
  // --------------------------------------------------

  Future<void> increaseProgress(String habitId) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (index == -1) {
      return;
    }

    final habit = _habits[index];

    final today = DateTime.now();

    if (!habit.isScheduledForDate(today)) {
      return;
    }

    if (habit.todayProgress >= habit.target) {
      return;
    }

    final newProgress = habit.todayProgress + 1;

    await _updateTodayCompletion(
      index,
      newProgress,
    );
  }

  // --------------------------------------------------
  // DECREASE PROGRESS
  // --------------------------------------------------

  Future<void> decreaseProgress(String habitId) async {
    final index = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (index == -1) {
      return;
    }

    final habit = _habits[index];

    final today = DateTime.now();

    if (!habit.isScheduledForDate(today)) {
      return;
    }

    if (habit.todayProgress <= 0) return;

    final existing = habit.completionForDate(today);
    if (existing?.isCompleted == true && !existing!.canUndo) {
      return;
    }

    final newProgress = habit.todayProgress - 1;
    await _updateTodayCompletion(index, newProgress);
  }

  // --------------------------------------------------
  // UPDATE TODAY'S COMPLETION
  // --------------------------------------------------

  Future<void> _updateTodayCompletion(
      int index,
      int newProgress,
      ) async {
    final habit = _habits[index];

    final today = DateTime.now();

    final todayDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    if (!habit.isScheduledForDate(todayDate)) {
      return;
    }

    final updatedCompletions =
        List<HabitCompletion>.from(habit.completions);

    final existingIndex = updatedCompletions.indexWhere(
      (item) => _isSameDay(item.date, todayDate),
    );

    // Preserve an existing note when the user changes today's measurable
    // progress. Updating the counter must never silently erase user data.
    final existingNote = existingIndex >= 0
        ? updatedCompletions[existingIndex].note
        : null;

    final existing = existingIndex >= 0
        ? updatedCompletions[existingIndex]
        : null;
    final wasCompleted = habit.todayProgress >= habit.target;
    final completedNow = newProgress >= habit.target;
    final completion = HabitCompletion(
      date: todayDate,
      value: newProgress,
      target: habit.target,
      note: existingNote,
      completedAt: completedNow
          ? (wasCompleted ? existing?.completedAt : DateTime.now())
          : null,
    );

    if (existingIndex >= 0) {
      updatedCompletions[existingIndex] = completion;
    } else {
      updatedCompletions.add(completion);
    }

    _habits[index] = habit.copyWith(
      todayProgress: newProgress,
      completions: updatedCompletions,
    );

    notifyListeners();

    // Persist after the UI has already reflected the tap.
    // This removes the noticeable lag on completion/undo.
    unawaited(_save());
    if (!wasCompleted && completedNow && LocalStorageService.loadNotificationsEnabled()) {
      unawaited(NotificationService.showActivityNotification(
        title: '🔥 Habit completed',
        body: 'Great work — “${habit.name}” is complete for today!',
      ));
    }
  }

  // --------------------------------------------------
  // NOTES / FORGOTTEN COMPLETION
  // --------------------------------------------------

  Future<bool> updateNote(String habitId, DateTime date, String? note) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return false;
    final habit = _habits[index];
    final completion = habit.completionForDate(date);
    if (completion == null) return false;
    final list = List<HabitCompletion>.from(habit.completions);
    final i = list.indexWhere((c) => _isSameDay(c.date, date));
    final trimmed = note?.trim();
    list[i] = trimmed == null || trimmed.isEmpty
        ? completion.copyWith(clearNote: true)
        : completion.copyWith(note: trimmed);
    _habits[index] = habit.copyWith(completions: list);
    notifyListeners();
    await _save();
    if (trimmed != null && trimmed.isNotEmpty && LocalStorageService.loadNotificationsEnabled()) {
      await NotificationService.showActivityNotification(title: '📝 Note added', body: 'A note was saved for “${habit.name}”.');
    }
    return true;
  }

  Future<bool> completeForgottenDay(String habitId, DateTime date) async {
    final index = _habits.indexWhere((h) => h.id == habitId);
    if (index == -1) return false;
    final habit = _habits[index];
    final day = _dateOnly(date);
    final yesterday = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    if (day != yesterday || !habit.isNormallyScheduledForDate(day) ||
        habit.isPausedOnDate(day) || habit.completionForDate(day) != null) {
      return false;
    }
    final list = List<HabitCompletion>.from(habit.completions)
      ..add(HabitCompletion(
        date: day,
        value: habit.target,
        target: habit.target,
        completedAt: DateTime.now(),
      ));
    _habits[index] = habit.copyWith(completions: list);
    notifyListeners();
    await _save();
    return true;
  }

  // --------------------------------------------------
  // GET COMPLETION FOR A DATE
  // --------------------------------------------------

  HabitCompletion? getCompletionForDate(
      String habitId,
      DateTime date,
      ) {
    final habitIndex = _habits.indexWhere(
          (habit) => habit.id == habitId,
    );

    if (habitIndex == -1) {
      return null;
    }

    return _habits[habitIndex].completionForDate(date);
  }

  // --------------------------------------------------
  // CLEAR ALL HABITS
  // --------------------------------------------------

  Future<void> clearHabits() async {
    _habits.clear();

    notifyListeners();

    await _save();
  }

  // --------------------------------------------------
  // SAVE
  // --------------------------------------------------

  Future<void> _save() async {
    await LocalStorageService.saveHabits(
      _habits,
    );
  }

  bool _sameDays(List<int> a, List<int> b) {
    final aa = [...a]..sort();
    final bb = [...b]..sort();
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
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

  // --------------------------------------------------
  // SAME DAY CHECK
  // --------------------------------------------------

  bool _isSameDay(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}