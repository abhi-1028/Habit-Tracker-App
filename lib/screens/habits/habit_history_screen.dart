import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../models/habit_completion.dart';
import '../../models/habit_pause.dart';
import '../../services/habit_store.dart';

class HabitHistoryScreen extends StatefulWidget {
  final Habit habit;

  const HabitHistoryScreen({
    super.key,
    required this.habit,
  });

  @override
  State<HabitHistoryScreen> createState() => _HabitHistoryScreenState();
}

class _HabitHistoryScreenState extends State<HabitHistoryScreen> {
  late Habit _habit;

  Habit get habit => _habit;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    HabitStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    final updated = HabitStore.instance.habits.where((h) => h.id == widget.habit.id);
    if (!mounted || updated.isEmpty) return;
    setState(() => _habit = updated.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();

    final firstDayOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final daysInMonth = DateTime(
      now.year,
      now.month + 1,
      0,
    ).day;

    final firstWeekday = firstDayOfMonth.weekday;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatistics(
              context,
              theme,
            ),

            const SizedBox(height: 14),

            _buildAddedDateCard(theme),

            const SizedBox(height: 28),

            Text(
              _monthName(now.month),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            _buildWeekdayHeader(theme),

            const SizedBox(height: 8),

            _buildCalendar(
              context,
              theme,
              now,
              daysInMonth,
              firstWeekday,
            ),

            const SizedBox(height: 20),

            _buildLegend(theme),

            const SizedBox(height: 28),

            Text(
              'Completion History',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildCompletionHistory(
              context,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddedDateCard(ThemeData theme) {
    final created = habit.createdAt ?? habit.creationDate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Habit added on ${_formatDate(created)}',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STATISTICS
  // ------------------------------------------------------------

  Widget _buildStatistics(
      BuildContext context,
      ThemeData theme,
      ) {
    final completionPercentage =
    _calculateCompletionPercentage();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                theme,
                icon: '🔥',
                value: '${habit.currentStreak}',
                label: 'Current streak',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildStatCard(
                theme,
                icon: '🏆',
                value: '${habit.bestStreak}',
                label: 'Best streak',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: completionPercentage / 100,
                        strokeWidth: 6,
                        backgroundColor: theme
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      Text(
                        '${completionPercentage.round()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Completion',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Based on scheduled days',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      ThemeData theme, {
        required String icon,
        required String value,
        required String label,
      }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              icon,
              style: const TextStyle(
                fontSize: 28,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // COMPLETION PERCENTAGE
  // ------------------------------------------------------------

  double _calculateCompletionPercentage() {
    final today = DateTime.now();

    final firstCompletionDate =
    habit.completions.isEmpty
        ? DateTime(
      today.year,
      today.month,
      today.day,
    )
        : habit.completions
        .map(
          (completion) => DateTime(
        completion.date.year,
        completion.date.month,
        completion.date.day,
      ),
    )
        .reduce(
          (a, b) => a.isBefore(b) ? a : b,
    );

    final startDate = DateTime(
      firstCompletionDate.year,
      firstCompletionDate.month,
      firstCompletionDate.day,
    );

    final endDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    int scheduledDays = 0;
    int completedDays = 0;

    DateTime currentDate = startDate;

    while (!currentDate.isAfter(endDate)) {
      if (habit.isScheduledForDate(currentDate)) {
        scheduledDays++;

        final completion =
        habit.completionForDate(currentDate);

        if (completion?.isCompleted ?? false) {
          completedDays++;
        }
      }

      currentDate = currentDate.add(
        const Duration(days: 1),
      );
    }

    if (scheduledDays == 0) {
      return 0;
    }

    return (completedDays / scheduledDays) * 100;
  }

  // ------------------------------------------------------------
  // WEEKDAY HEADER
  // ------------------------------------------------------------

  Widget _buildWeekdayHeader(ThemeData theme) {
    const weekdays = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];

    return Row(
      children: weekdays.map(
            (day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style:
                theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ------------------------------------------------------------
  // CALENDAR
  // ------------------------------------------------------------

  Widget _buildCalendar(
      BuildContext context,
      ThemeData theme,
      DateTime now,
      int daysInMonth,
      int firstWeekday,
      ) {
    final cells = <Widget>[];

    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        now.year,
        now.month,
        day,
      );

      cells.add(
        _buildDayCell(
          context,
          theme,
          date,
          now,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 6,
      childAspectRatio: 1,
      children: cells,
    );
  }

  // ------------------------------------------------------------
  // DAY CELL
  // ------------------------------------------------------------

  Widget _buildDayCell(
      BuildContext context,
      ThemeData theme,
      DateTime date,
      DateTime today,
      ) {
    final completion = habit.completionForDate(date);
    final status = habit.statusForDate(date);
    final isPaused = status == HabitDayStatus.paused;
    final isScheduled = habit.isNormallyScheduledForDate(date);
    final isCompleted = status == HabitDayStatus.completed;
    final isToday = _isSameDay(date, today);

    Color backgroundColor;
    Color textColor;

    if (status == HabitDayStatus.beforeCreation) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    } else if (isPaused) {
      backgroundColor = theme.colorScheme.secondaryContainer;
      textColor = theme.colorScheme.onSecondaryContainer;
    } else if (status == HabitDayStatus.notScheduled) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    } else if (status == HabitDayStatus.future) {
      backgroundColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.45);
      textColor = theme.colorScheme.onPrimaryContainer;
    } else if (isCompleted) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (status == HabitDayStatus.missed) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: () {
        _showDayDetails(
          context,
          date,
          completion,
          isScheduled,
          isPaused,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius:
          BorderRadius.circular(12),
          border: isToday
              ? Border.all(
            color:
            theme.colorScheme.primary,
            width: 2,
          )
              : null,
        ),
        child: Center(
          child: status == HabitDayStatus.future
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${date.day}', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .7),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          )
              : isPaused
              ? Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pause,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color: textColor,
                  fontSize: 12,
                ),
              ),
            ],
          )
              : Text(
            '${date.day}',
            style: TextStyle(
              fontWeight:
              isToday || isCompleted
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CALENDAR LEGEND
  // ------------------------------------------------------------

  Widget _buildLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(
          theme,
          color:
          theme.colorScheme.primary,
          label: 'Completed',
        ),

        _buildLegendItem(
          theme,
          color:
          theme.colorScheme.errorContainer,
          label: 'Incomplete',
        ),

        _buildLegendItem(
          theme,
          color: theme
              .colorScheme
              .surfaceContainerHighest,
          label: 'Scheduled',
        ),

        _buildLegendItem(
          theme,
          color: theme
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.45),
          label: 'Not scheduled',
        ),

        _buildLegendItem(
          theme,
          color:
          theme.colorScheme.secondaryContainer,
          label: 'Paused',
        ),
      ],
    );
  }

  Widget _buildLegendItem(
      ThemeData theme, {
        required Color color,
        required String label,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
            BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style:
          theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // COMPLETION HISTORY
  // ------------------------------------------------------------

  Widget _buildCompletionHistory(
      BuildContext context,
      ThemeData theme,
      ) {
    final completions =
    [...habit.completions];

    completions.sort(
          (a, b) => b.date.compareTo(a.date),
    );

    if (completions.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding:
          const EdgeInsets.all(20),
          child: Text(
            'No completion history yet.',
            style:
            theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Column(
      children: completions.map(
            (completion) {
          final completed =
              completion.isCompleted;

          return Card(
            elevation: 0,
            margin:
            const EdgeInsets.only(
              bottom: 10,
            ),
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color: completed
                      ? theme
                      .colorScheme
                      .primary
                      .withValues(
                    alpha: 0.15,
                  )
                      : theme
                      .colorScheme
                      .error
                      .withValues(
                    alpha: 0.15,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed
                      ? Icons.check
                      : Icons.close,
                  color: completed
                      ? theme
                      .colorScheme
                      .primary
                      : theme
                      .colorScheme
                      .error,
                ),
              ),

              title: Text(
                _formatDate(
                  completion.date,
                ),
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              subtitle: Text(
                '${completion.value} / '
                    '${completion.target}'
                    '${habit.unit.isNotEmpty ? ' ${habit.unit}' : ''}',
              ),

              trailing: completed
                  ? const Text(
                'Completed',
                style:
                TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              )
                  : const Text(
                'Incomplete',
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ------------------------------------------------------------
  // DAY DETAILS
  // ------------------------------------------------------------

  Widget _buildPendingDetails(BuildContext context, ThemeData theme, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.radio_button_unchecked),
          title: Text('Scheduled today and not completed yet.'),
        ),
        if (_isYesterday(date))
          const SizedBox.shrink(),
      ],
    );
  }

  bool _isYesterday(DateTime date) {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    return _isSameDay(date, yesterday);
  }

  void _showDayDetails(
      BuildContext context,
      DateTime date,
      HabitCompletion? completion,
      bool isScheduled,
      bool isPaused,
      ) {
    final theme = Theme.of(context);
    final status = habit.statusForDate(date);
    final isCompleted = completion?.isCompleted ?? false;
    final pause = habit.pauseForDate(date);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final details = <Widget>[
          Text(
            _formatDate(date),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ];

        if (status == HabitDayStatus.beforeCreation) {
          details.add(
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_toggle_off),
              title: Text('This habit did not exist on this date.'),
            ),
          );
        } else if (status == HabitDayStatus.paused) {
          details.add(
            _buildPausedDetails(sheetContext, theme, pause),
          );
        } else if (status == HabitDayStatus.notScheduled) {
          details.add(
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_busy_outlined),
              title: Text('This habit was not scheduled for this day.'),
            ),
          );
        } else if (status == HabitDayStatus.future) {
          details.add(
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event),
              title: Text('This is a future scheduled day.'),
            ),
          );
        } else if (status == HabitDayStatus.pending) {
          details.add(
            _buildPendingDetails(sheetContext, theme, date),
          );
        } else if (status == HabitDayStatus.missed && completion == null) {
          details.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cancel_outlined),
                  title: Text('Missed — no completion was recorded.'),
                ),
                if (_isYesterday(date))
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await HabitStore.instance
                          .completeForgottenDay(habit.id, date);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Yesterday marked complete.'
                                : 'Unable to update yesterday.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Mark as completed'),
                  ),
              ],
            ),
          );
        } else if (completion != null) {
          final selectedCompletion = completion;
          details.add(
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.cancel,
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                Text(
                  isCompleted ? 'Completed' : 'Incomplete',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );

          details.add(const SizedBox(height: 12));

          details.add(
            Text(
              'Progress: ${selectedCompletion.value} / ${selectedCompletion.target}'
              '${habit.unit.isNotEmpty ? ' ${habit.unit}' : ''}',
            ),
          );

          final note = selectedCompletion.note?.trim();
          if (note != null && note.isNotEmpty) {
            details.add(const SizedBox(height: 12));
            details.add(
              Text(
                'Note',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
            details.add(const SizedBox(height: 4));
            details.add(Text(note));
          }

          details.add(const SizedBox(height: 12));
          details.add(
            OutlinedButton.icon(
              onPressed: () async {
                final result = await showDialog<_NoteEditResult?>(
                  context: sheetContext,
                  builder: (_) => _HistoryNoteDialog(
                    initialNote: selectedCompletion.note ?? '',
                  ),
                );

                if (result != null) {
                  await HabitStore.instance.updateNote(
                    habit.id,
                    date,
                    result.note,
                  );
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                }
              },
              icon: const Icon(Icons.note_alt_outlined),
              label: Text(
                selectedCompletion.note?.trim().isNotEmpty == true
                    ? 'Edit note'
                    : 'Add note',
              ),
            ),
          );
          if (selectedCompletion.note?.trim().isNotEmpty == true) {
            details.add(
              const SizedBox(height: 8),
            );
            details.add(
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Delete note?'),
                      content: const Text('This removes the note for this completion.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await HabitStore.instance.updateNote(habit.id, date, null);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete note'),
              ),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: details,
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // PAUSED DAY DETAILS
  // ------------------------------------------------------------

  Widget _buildPausedDetails(
      BuildContext context,
      ThemeData theme,
      HabitPause? pause,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.pause_circle,
              color: theme
                  .colorScheme
                  .secondary,
            ),

            const SizedBox(width: 10),

            const Text(
              'Paused',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),

        if (pause != null) ...[
          const SizedBox(height: 16),

          Text(
            'Pause period',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${_formatDate(pause.startDate)}'
                ' → '
                '${_formatDate(pause.endDate)}',
          ),

          if (pause.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              'Reason',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              pause.reason,
            ),
          ],
        ],
      ],
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  bool _isSameDay(
      DateTime first,
      DateTime second,
      ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _NoteEditResult {
  final String note;
  const _NoteEditResult(this.note);
}

class _HistoryNoteDialog extends StatefulWidget {
  final String initialNote;

  const _HistoryNoteDialog({required this.initialNote});

  @override
  State<_HistoryNoteDialog> createState() => _HistoryNoteDialogState();
}

class _HistoryNoteDialogState extends State<_HistoryNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Optional note',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _NoteEditResult(_controller.text),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
