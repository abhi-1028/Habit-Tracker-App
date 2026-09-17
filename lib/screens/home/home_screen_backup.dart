import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _increaseProgress(Habit habit) {
    _habitStore.increaseProgress(habit.id);
  }

  void _decreaseProgress(Habit habit) {
    _habitStore.decreaseProgress(habit.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habits = _habitStore.habits;

    final completedCount =
        habits.where((habit) => habit.isCompleted).length;

    final totalCount = habits.length;

    final progress =
    totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(theme),

              const SizedBox(height: 24),

              _buildProgressCard(
                theme,
                completedCount,
                totalCount,
                progress,
              ),

              const SizedBox(height: 28),

              _buildSectionTitle('Today\'s Habits'),

              const SizedBox(height: 12),

              if (habits.isEmpty)
                _buildEmptyHabitsCard(theme)
              else
                ...habits.map(
                      (habit) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildHabitCard(
                      theme,
                      habit,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              _buildSectionTitle('🔥 Streak Highlights'),

              const SizedBox(height: 12),

              _buildStreakHighlights(
                theme,
                habits,
              ),

              const SizedBox(height: 28),

              _buildSectionTitle('Motivational Insight'),

              const SizedBox(height: 12),

              _buildInsightCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(ThemeData theme) {
    final hour = DateTime.now().hour;

    String greeting;

    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, there! 👋',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to keep your streaks going? 🔥',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(
      ThemeData theme,
      int completedCount,
      int totalCount,
      double progress,
      ) {
    final percentage = (progress * 100).round();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 9,
                    backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$completedCount of $totalCount habits completed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyHabitsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No habits for today',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first habit from the Habits section.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(
      ThemeData theme,
      Habit habit,
      ) {
    final isMeasurable =
        habit.type == HabitType.measurable;

    final isCompleted = habit.isCompleted;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted
                    ? theme.colorScheme.primary
                    .withValues(alpha: 0.18)
                    : theme.colorScheme.primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle
                    : isMeasurable
                    ? Icons.track_changes_outlined
                    : Icons.check_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isMeasurable
                        ? '${habit.todayProgress} / '
                        '${habit.target} ${habit.unit}'
                        : isCompleted
                        ? 'Completed'
                        : 'Not completed',
                    style: TextStyle(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  if (isMeasurable) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: habit.target == 0
                          ? 0
                          : habit.todayProgress /
                          habit.target,
                      minHeight: 5,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            if (isMeasurable)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed:
                    habit.todayProgress > 0
                        ? () => _decreaseProgress(
                      habit,
                    )
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    onPressed: habit.isCompleted
                        ? null
                        : () => _increaseProgress(
                      habit,
                    ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              )
            else
              IconButton(
                onPressed: isCompleted
                    ? () => _decreaseProgress(
                  habit,
                )
                    : () => _increaseProgress(
                  habit,
                ),
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakHighlights(
      ThemeData theme,
      List<Habit> habits,
      ) {
    if (habits.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Complete a habit today to start building your streak.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Column(
      children: habits.map(
            (habit) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Text(
                '🔥',
                style: TextStyle(fontSize: 26),
              ),
              title: Text(
                habit.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                habit.currentStreak == 0
                    ? 'Start your streak today'
                    : '${habit.currentStreak} day'
                    '${habit.currentStreak == 1 ? '' : 's'} streak',
              ),
              trailing: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Text(
                    '${habit.currentStreak}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                      theme.colorScheme.primary,
                    ),
                  ),
                  const Text(
                    'current',
                    style: TextStyle(
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildInsightCard(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '💡',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Every small step counts. Start with one habit and keep going!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}