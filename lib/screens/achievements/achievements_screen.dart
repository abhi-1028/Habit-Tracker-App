import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habits = _habitStore.habits;

    final achievements = _buildAchievements(habits);

    final unlockedCount =
        achievements.where((achievement) => achievement.unlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: habits.isEmpty
          ? _buildEmptyState(theme)
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(
              theme,
              unlockedCount,
              achievements.length,
            ),

            const SizedBox(height: 28),

            Text(
              'Your Achievements',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...achievements.map(
                  (achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAchievementCard(
                  theme,
                  achievement,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 20),

            Text(
              'No achievements yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Create a habit and start completing it to unlock achievements.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY CARD
  // ------------------------------------------------------------

  Widget _buildSummaryCard(
      ThemeData theme,
      int unlockedCount,
      int totalCount,
      ) {
    final progress =
    totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount of $totalCount unlocked',
                        style:
                        theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Keep building your habits!',
                        style:
                        theme.textTheme.bodyMedium?.copyWith(
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

            const SizedBox(height: 18),

            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACHIEVEMENT CARD
  // ------------------------------------------------------------

  Widget _buildAchievementCard(
      ThemeData theme,
      Achievement achievement,
      ) {
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: achievement.unlocked
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: achievement.unlocked
                    ? colorScheme.primary
                    : colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievement.icon,
                size: 28,
                color: achievement.unlocked
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style:
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: achievement.unlocked
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    achievement.description,
                    style:
                    theme.textTheme.bodyMedium?.copyWith(
                      color: achievement.unlocked
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Icon(
              achievement.unlocked
                  ? Icons.check_circle
                  : Icons.lock_outline,
              color: achievement.unlocked
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACHIEVEMENTS
  // ------------------------------------------------------------

  List<Achievement> _buildAchievements(
      List<Habit> habits,
      ) {
    final hasAnyCompletion = habits.any(
          (habit) => habit.completions.any(
            (completion) => completion.isCompleted,
      ),
    );

    final bestStreak = habits.isEmpty
        ? 0
        : habits
        .map((habit) => habit.bestStreak)
        .reduce(
          (a, b) => a > b ? a : b,
    );

    final perfectDay = _hasPerfectDay(habits);

    final completionDays = _getCompletionDays(habits);
    final totalHabits = habits.length;
    final completedActions = habits.fold<int>(0, (sum, h) => sum + h.completions.where((c) => c.isCompleted).length);

    return [
      Achievement(
        title: 'First Step',
        description:
        'Complete a habit for the first time.',
        icon: Icons.flag_outlined,
        unlocked: hasAnyCompletion,
      ),

      Achievement(
        title: '3 Day Streak',
        description:
        'Reach a 3-day habit streak.',
        icon: Icons.local_fire_department_outlined,
        unlocked: bestStreak >= 3,
      ),

      Achievement(
        title: '7 Day Streak',
        description:
        'Reach a 7-day habit streak.',
        icon: Icons.local_fire_department_outlined,
        unlocked: bestStreak >= 7,
      ),

      Achievement(
        title: '14 Day Streak',
        description:
        'Reach a 14-day habit streak.',
        icon: Icons.local_fire_department_outlined,
        unlocked: bestStreak >= 14,
      ),

      Achievement(
        title: '30 Day Streak',
        description:
        'Reach a 30-day habit streak.',
        icon: Icons.local_fire_department_outlined,
        unlocked: bestStreak >= 30,
      ),

      Achievement(
        title: 'Perfect Day',
        description:
        'Complete every habit scheduled for one day.',
        icon: Icons.star_outline,
        unlocked: perfectDay,
      ),

      Achievement(
        title: '10 Completion Days',
        description:
        'Complete habits on 10 different days.',
        icon: Icons.calendar_month_outlined,
        unlocked: completionDays.length >= 10,
      ),

      Achievement(
        title: '30 Completion Days',
        description:
        'Complete habits on 30 different days.',
        icon: Icons.workspace_premium_outlined,
        unlocked: completionDays.length >= 30,
      ),

      Achievement(title: '50 Completion Days', description: 'Keep a habit rhythm for 50 days.', icon: Icons.auto_awesome_outlined, unlocked: completionDays.length >= 50),
      Achievement(title: '100 Completion Days', description: 'Reach 100 days of completed habits.', icon: Icons.diamond_outlined, unlocked: completionDays.length >= 100),
      Achievement(title: 'Habit Collector', description: 'Create 5 habits and build your routine.', icon: Icons.collections_bookmark_outlined, unlocked: totalHabits >= 5),
      Achievement(title: '100 Wins', description: 'Complete 100 habit actions.', icon: Icons.celebration_outlined, unlocked: completedActions >= 100),
    ];
  }

  // ------------------------------------------------------------
  // PERFECT DAY
  // ------------------------------------------------------------

  bool _hasPerfectDay(List<Habit> habits) {
    if (habits.isEmpty) {
      return false;
    }

    final allDates = <DateTime>{};

    for (final habit in habits) {
      for (final completion in habit.completions) {
        if (completion.isCompleted) {
          allDates.add(
            DateTime(
              completion.date.year,
              completion.date.month,
              completion.date.day,
            ),
          );
        }
      }
    }

    for (final date in allDates) {
      final scheduledHabits = habits.where(
            (habit) => habit.isScheduledForDate(date),
      );

      if (scheduledHabits.isEmpty) {
        continue;
      }

      final everyScheduledHabitCompleted =
      scheduledHabits.every(
            (habit) {
          final completion =
          habit.completionForDate(date);

          return completion?.isCompleted == true;
        },
      );

      if (everyScheduledHabitCompleted) {
        return true;
      }
    }

    return false;
  }

  // ------------------------------------------------------------
  // COMPLETION DAYS
  // ------------------------------------------------------------

  Set<DateTime> _getCompletionDays(
      List<Habit> habits,
      ) {
    final dates = <DateTime>{};

    for (final habit in habits) {
      for (final completion in habit.completions) {
        if (completion.isCompleted) {
          dates.add(
            DateTime(
              completion.date.year,
              completion.date.month,
              completion.date.day,
            ),
          );
        }
      }
    }

    return dates;
  }
}

// ============================================================
// ACHIEVEMENT MODEL
// ============================================================

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  const Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}