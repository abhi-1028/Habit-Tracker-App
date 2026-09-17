import 'package:flutter/material.dart';

import '../../core/habit_visuals.dart';

import '../../models/habit.dart';
import '../../models/habit_pause.dart';
import '../../services/habit_store.dart';
import 'add_habit_screen.dart';
import 'edit_habit_screen.dart';
import 'habit_history_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitStore _habitStore = HabitStore.instance;

  @override
  void initState() {
    super.initState();
    _habitStore.addListener(_onHabitsChanged);
  }

  @override
  void dispose() {
    _habitStore.removeListener(_onHabitsChanged);
    super.dispose();
  }

  void _onHabitsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // --------------------------------------------------
  // ADD HABIT
  // --------------------------------------------------

  Future<void> _addHabit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHabitScreen(),
      ),
    );
  }

  // --------------------------------------------------
  // EDIT HABIT
  // --------------------------------------------------

  Future<void> _editHabit(Habit habit) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditHabitScreen(
          habit: habit,
        ),
      ),
    );
  }

  Future<void> _archiveHabit(Habit habit) async {
    await _habitStore.setArchived(habit.id, !habit.isArchived);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        habit.isArchived ? '${habit.name} restored.' : '${habit.name} archived.'
      )),
    );
  }

  // --------------------------------------------------
  // DELETE HABIT
  // --------------------------------------------------

  Future<void> _deleteHabit(Habit habit) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Habit?'),
          content: Text(
            'Are you sure you want to delete "${habit.name}"?\n\n'
                'This will permanently remove the habit and its '
                'completion history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await _habitStore.removeHabit(habit.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${habit.name}" was deleted.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --------------------------------------------------
  // OPEN HISTORY
  // --------------------------------------------------

  void _openHabitHistory(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitHistoryScreen(
          habit: habit,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PAUSE HABIT
  // --------------------------------------------------

  Future<void> _pauseHabit(Habit habit) async {
    final result = await showDialog<_PauseFormResult>(
      context: context,
      builder: (context) {
        return _PauseHabitDialog(
          habit: habit,
        );
      },
    );

    if (result == null) {
      return;
    }

    final success = await _habitStore.pauseHabit(
      habitId: habit.id,
      startDate: result.startDate,
      endDate: result.endDate,
      reason: result.reason,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This pause overlaps an existing pause period.',
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${habit.name} is paused until '
              '${_formatShortDate(result.endDate)}.',
        ),
      ),
    );
  }

  // --------------------------------------------------
  // RESUME HABIT
  // --------------------------------------------------

  Future<void> _resumeHabit(Habit habit) async {
    final activePause = habit.activePause;

    if (activePause == null) {
      return;
    }

    final shouldResume = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resume Habit?'),
          content: Text(
            'Your "${habit.name}" habit is currently paused.\n\n'
                'Would you like to resume it today?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Keep Paused'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );

    if (shouldResume != true) {
      return;
    }

    final success = await _habitStore.resumeHabit(
      habit.id,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to resume this habit.',
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${habit.name} has resumed. Welcome back! 🔥',
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PAUSE HISTORY
  // --------------------------------------------------

  void _showPauseHistory(Habit habit) {
    final pauses = [...habit.pauses];

    pauses.sort(
          (a, b) => b.startDate.compareTo(a.startDate),
    );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pause History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  habit.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 20),

                if (pauses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No pause history yet.',
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pauses.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pause = pauses[index];

                        return _buildPauseHistoryItem(
                          context,
                          pause,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPauseHistoryItem(
      BuildContext context,
      HabitPause pause,
      ) {
    final theme = Theme.of(context);

    final isActive = pause.isActive;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isActive
                  ? Icons.pause_circle_filled
                  : Icons.pause_circle_outline,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatShortDate(pause.startDate)}'
                        ' → '
                        '${_formatShortDate(pause.endDate)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    pause.reason,
                    style: theme.textTheme.bodyMedium,
                  ),

                  if (isActive) ...[
                    const SizedBox(height: 6),

                    Text(
                      'Currently paused',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForHabit(Habit habit) {
    const icons = {
      'check': Icons.check_circle,
      'water': Icons.water_drop,
      'book': Icons.menu_book,
      'fitness': Icons.fitness_center,
      'meditate': Icons.self_improvement,
      'sleep': Icons.bedtime,
      'work': Icons.work_outline,
      'heart': Icons.favorite,
      'walk': Icons.directions_walk,
      'run': Icons.directions_run,
      'music': Icons.music_note,
      'code': Icons.code,
      'school': Icons.school,
      'food': Icons.restaurant,
      'coffee': Icons.local_cafe,
      'sun': Icons.wb_sunny,
      'star': Icons.star,
      'bolt': Icons.bolt,
      'selfcare': Icons.spa,
      'journal': Icons.edit_note,
      'phone': Icons.phone_android,
      'money': Icons.savings,
      'language': Icons.language,
      'brush': Icons.brush,
      'camera': Icons.camera_alt,
      'pets': Icons.pets,
      'garden': Icons.local_florist,
      'home': Icons.home,
    };
    return icons[habit.icon] ?? Icons.check_circle;
  }

  // --------------------------------------------------
  // SCHEDULE TEXT
  // --------------------------------------------------

  String _getScheduleText(Habit habit) {
    if (habit.scheduleType == HabitScheduleType.daily) {
      return 'Every day';
    }

    const weekdayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    final days = habit.scheduledWeekdays
        .map((day) => weekdayNames[day])
        .whereType<String>()
        .toList();

    if (days.isEmpty) {
      return 'No days selected';
    }

    return days.join(', ');
  }

  // --------------------------------------------------
  // DATE FORMAT
  // --------------------------------------------------

  String _formatShortDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habits = _habitStore.habits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHabit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Habit'),
      ),

      body: habits.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.track_changes_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(height: 20),

              Text(
                'No habits yet',
                style:
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Start with one small habit and build from there.',
                textAlign: TextAlign.center,
                style:
                theme.textTheme.bodyLarge?.copyWith(
                  color:
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: habits.length,
        itemBuilder: (context, index) {
          final habit = habits[index];
          final isPaused = habit.isPaused;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: ListTile(
              onTap: () {
                _openHabitHistory(habit);
              },

              // --------------------------------------------------
              // HABIT ICON
              // --------------------------------------------------

              leading: CircleAvatar(
                backgroundColor: Color(habit.colorValue).withValues(alpha: 0.14),
                child: isPaused
                    ? Icon(Icons.pause, color: Color(habit.colorValue))
                    : HabitVisuals.icon(
                        habit.icon,
                        size: 20,
                        color: Color(habit.colorValue),
                      ),
              ),

              // --------------------------------------------------
              // TITLE
              // --------------------------------------------------

              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      habit.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (habit.isArchived)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Archived', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  if (isPaused)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme
                            .colorScheme
                            .secondaryContainer,
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Paused',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w600,
                          color: theme
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),

              // --------------------------------------------------
              // SUBTITLE
              // --------------------------------------------------

              subtitle: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),

                  Text(
                    habit.type ==
                        HabitType.measurable
                        ? '${habit.target} ${habit.unit}'
                        : 'Yes / No',
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color:
                        theme.colorScheme.primary,
                      ),

                      const SizedBox(width: 5),

                      Flexible(
                        child: Text(
                          _getScheduleText(habit),
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: theme
                                .colorScheme
                                .primary,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (isPaused &&
                      habit.activePause != null) ...[
                    const SizedBox(height: 4),

                    Text(
                      'Paused until '
                          '${_formatShortDate(habit.activePause!.endDate)}',
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
                ],
              ),

              // --------------------------------------------------
              // TRAILING
              // --------------------------------------------------

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPaused)
                    Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            const Text('🔥'),
                            const SizedBox(width: 4),
                            Text(
                              '${habit.currentStreak}',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'History',
                          style: theme
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color: theme
                                .colorScheme
                                .primary,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(width: 8),

                  PopupMenuButton<String>(
                    tooltip: 'Habit options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editHabit(habit);
                      } else if (value == 'pause') {
                        _pauseHabit(habit);
                      } else if (value == 'resume') {
                        _resumeHabit(habit);
                      } else if (value ==
                          'pause_history') {
                        _showPauseHistory(habit);
                      } else if (value == 'archive') {
                        _archiveHabit(habit);
                      } else if (value == 'delete') {
                        _deleteHabit(habit);
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                              ),
                              SizedBox(width: 12),
                              Text('Edit Habit'),
                            ],
                          ),
                        ),

                        PopupMenuItem<String>(
                          value: isPaused
                              ? 'resume'
                              : 'pause',
                          child: Row(
                            children: [
                              Icon(
                                isPaused
                                    ? Icons
                                    .play_arrow_outlined
                                    : Icons
                                    .pause_outlined,
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Text(
                                isPaused
                                    ? 'Resume Habit'
                                    : 'Pause Habit',
                              ),
                            ],
                          ),
                        ),

                        if (habit.pauses.isNotEmpty)
                          const PopupMenuItem<String>(
                            value: 'pause_history',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .history_outlined,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Pause History',
                                ),
                              ],
                            ),
                          ),

                        const PopupMenuDivider(),

                        PopupMenuItem<String>(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(habit.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                              const SizedBox(width: 12),
                              Text(habit.isArchived ? 'Restore Habit' : 'Archive Habit'),
                            ],
                          ),
                        ),

                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                              ),
                              SizedBox(width: 12),
                              Text('Delete Habit'),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),

    );
  }
}

// ============================================================
// PAUSE FORM RESULT
// ============================================================

class _PauseFormResult {
  final DateTime startDate;
  final DateTime endDate;
  final String reason;

  const _PauseFormResult({
    required this.startDate,
    required this.endDate,
    required this.reason,
  });
}

// ============================================================
// PAUSE HABIT DIALOG
// ============================================================

class _PauseHabitDialog extends StatefulWidget {
  final Habit habit;

  const _PauseHabitDialog({
    required this.habit,
  });

  @override
  State<_PauseHabitDialog> createState() =>
      _PauseHabitDialogState();
}

class _PauseHabitDialogState
    extends State<_PauseHabitDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  String _reason = 'Other';

  // --------------------------------------------------
  // CUSTOM REASON
  // --------------------------------------------------

  final TextEditingController _customReasonController =
  TextEditingController();

  String? _customReasonError;

  // --------------------------------------------------
  // PREDEFINED REASONS
  // --------------------------------------------------

  final List<String> _reasons = const [
    'Exams',
    'Work',
    'Travel',
    'Health/rest',
    'Family commitments',
    'Mental wellbeing',
    'Other',
  ];

  // --------------------------------------------------
  // INIT
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();

    _startDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    _endDate = _startDate.add(
      const Duration(days: 6),
    );
  }

  // --------------------------------------------------
  // DISPOSE
  // --------------------------------------------------

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // START DATE
  // --------------------------------------------------

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  // --------------------------------------------------
  // END DATE
  // --------------------------------------------------

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate
          : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  // --------------------------------------------------
  // SUBMIT
  // --------------------------------------------------

  void _submit() {
    if (_endDate.isBefore(_startDate)) {
      return;
    }

    String finalReason = _reason;

    // --------------------------------------------------
    // OTHER REASON
    // --------------------------------------------------

    if (_reason == 'Other') {
      final customReason =
      _customReasonController.text.trim();

      if (customReason.isEmpty) {
        setState(() {
          _customReasonError =
          'Please enter a reason.';
        });

        return;
      }

      finalReason = customReason;
    }

    Navigator.pop(
      context,
      _PauseFormResult(
        startDate: _startDate,
        endDate: _endDate,
        reason: finalReason,
      ),
    );
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Pause Habit'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Take a break from "${widget.habit.name}". '
                  'Your streak will be protected during the pause.',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // START DATE
            // --------------------------------------------------

            Text(
              'Start date',
              style:
              theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            OutlinedButton.icon(
              onPressed: _selectStartDate,
              icon: const Icon(
                Icons.calendar_today_outlined,
              ),
              label: Text(
                _formatDate(_startDate),
              ),
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // END DATE
            // --------------------------------------------------

            Text(
              'End date',
              style:
              theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            OutlinedButton.icon(
              onPressed: _selectEndDate,
              icon: const Icon(
                Icons.event_outlined,
              ),
              label: Text(
                _formatDate(_endDate),
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // REASON
            // --------------------------------------------------

            Text(
              'Reason',
              style:
              theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 6),

            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _reasons.map(
                    (reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _reason = value;
                  _customReasonError = null;

                  // Clear the previous custom reason
                  // when selecting Other again.
                  if (value == 'Other') {
                    _customReasonController.clear();
                  }
                });
              },
            ),

            // --------------------------------------------------
            // CUSTOM OTHER REASON
            // --------------------------------------------------

            if (_reason == 'Other') ...[
              const SizedBox(height: 12),

              TextField(
                controller: _customReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type your reason...',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _customReasonError,
                ),
                onChanged: (_) {
                  if (_customReasonError != null) {
                    setState(() {
                      _customReasonError = null;
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 16),

            // --------------------------------------------------
            // RESUME INFORMATION
            // --------------------------------------------------

            Text(
              'You can resume this habit early at any time.',
              style:
              theme.textTheme.bodySmall?.copyWith(
                color:
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),

      // --------------------------------------------------
      // ACTIONS
      // --------------------------------------------------

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _submit,
          child: const Text('Pause Habit'),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // DATE FORMAT
  // --------------------------------------------------

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
}