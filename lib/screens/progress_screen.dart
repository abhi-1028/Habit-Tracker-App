import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/habit_visuals.dart';
import '../models/habit.dart';
import '../services/habit_store.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final HabitStore _store = HabitStore.instance;
  int _range = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Habit> get _habits => _store.habits.where((h) => !h.isArchived).toList();

  DateTime _start() {
    final today = _day(DateTime.now());
    switch (_range) {
      case 0:
        return today.subtract(Duration(days: today.weekday - 1));
      case 1:
        return DateTime(today.year, today.month, 1);
      case 2:
        return DateTime(today.year, 1, 1);
      default:
        DateTime? earliest;
        for (final h in _habits) {
          if (earliest == null || h.creationDate.isBefore(earliest)) {
            earliest = h.creationDate;
          }
        }
        return earliest ?? today;
    }
  }

  DateTime _end() {
    final today = _day(DateTime.now());
    if (_range == 0) return _start().add(const Duration(days: 6));
    return today;
  }

  Iterable<DateTime> _days() sync* {
    final start = _start();
    final today = _day(DateTime.now());
    final end = _end().isAfter(today) ? today : _end();
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      yield d;
    }
  }

  ({int scheduled, int completed}) _metric(DateTime date) {
    final scheduled = _habits.where((h) => h.isScheduledForDate(date)).toList();
    final completed = scheduled
        .where((h) => h.completionForDate(date)?.isCompleted ?? false)
        .length;
    return (scheduled: scheduled.length, completed: completed);
  }

  ({int scheduled, int completed}) _metricBetween(DateTime start, DateTime end) {
    var scheduled = 0;
    var completed = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final metric = _metric(d);
      scheduled += metric.scheduled;
      completed += metric.completed;
    }
    return (scheduled: scheduled, completed: completed);
  }

  List<({DateTime date, int scheduled, int completed})> get _rhythm {
    // Keep Week and Month as daily pulses. For Year and All time, aggregate
    // by month so the selected period visibly changes without creating
    // hundreds of unreadable bars.
    if (_range <= 1) {
      final result = <({DateTime date, int scheduled, int completed})>[];
      for (final d in _days()) {
        final metric = _metric(d);
        result.add((date: d, scheduled: metric.scheduled, completed: metric.completed));
      }
      return result;
    }

    final today = _day(DateTime.now());
    final start = _start();
    final result = <({DateTime date, int scheduled, int completed})>[];
    var cursor = DateTime(start.year, start.month, 1);

    while (!cursor.isAfter(today)) {
      final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
      final bucketEnd = nextMonth.subtract(const Duration(days: 1));
      final end = bucketEnd.isAfter(today) ? today : bucketEnd;
      final metric = _metricBetween(cursor, end);
      result.add((date: cursor, scheduled: metric.scheduled, completed: metric.completed));
      cursor = nextMonth;
    }
    return result;
  }

  double get _completionRate {
    var scheduled = 0;
    var completed = 0;
    for (final m in _rhythm) {
      scheduled += m.scheduled;
      completed += m.completed;
    }
    return scheduled == 0 ? 0 : completed / scheduled;
  }

  int get _completedActions =>
      _rhythm.fold(0, (sum, item) => sum + item.completed);

  int get _scheduledActions =>
      _rhythm.fold(0, (sum, item) => sum + item.scheduled);

  int get _perfectDays =>
      _rhythm.where((item) => item.scheduled > 0 && item.completed == item.scheduled).length;

  String get _rangeTitle => const ['Week', 'Month', 'Year', 'All time'][_range];

  String _dateLabel(DateTime d) {
    if (_range == 0) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
    }
    if (_range == 1) return '${d.day}/${d.month}';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[d.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = (_completionRate * 100).round();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: .06),
              Colors.transparent,
              cs.secondary.withValues(alpha: .035),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(child: _header(theme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _rangeSelector(theme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(key: ValueKey('hero-$_range-$_completedActions-$_scheduledActions'), child: _hero(theme, percent)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(child: _statGrid(theme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(key: ValueKey('rhythm-$_range-$_completedActions-$_scheduledActions'), child: _rhythmCard(theme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                sliver: SliverToBoxAdapter(child: _habitPulse(theme)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
                sliver: SliverToBoxAdapter(child: _insight(theme)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR PROGRESS', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2.2, color: cs.secondary)),
              const SizedBox(height: 6),
              Text('Momentum', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 3),
              Text('See how your consistency is moving.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: .12),
            border: Border.all(color: cs.primary.withValues(alpha: .28)),
          ),
          child: Icon(Icons.auto_graph_rounded, color: cs.primary),
        ),
      ],
    );
  }

  Widget _rangeSelector(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final selected = i == _range;
          final accent = i.isEven ? cs.primary : cs.secondary;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _range = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: .15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  const ['Week', 'Month', 'Year', 'All time'][i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected ? accent : cs.onSurface.withValues(alpha: .58),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _hero(ThemeData theme, int percent) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface,
            Color.alphaBlend(cs.primary.withValues(alpha: .08), cs.surface),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: cs.primary.withValues(alpha: .22)),
        boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: .08), blurRadius: 30)],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _completionRate),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CustomPaint(
                painter: _NeonRingPainter(
                  progress: value,
                  track: cs.outlineVariant,
                  colors: [cs.primary, cs.secondary, cs.tertiary],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$percent%', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w900)),
                      Text(_rangeTitle.toLowerCase(), style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: .55))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  percent >= 80 ? 'You are on fire.' : percent >= 50 ? 'Good momentum.' : 'Build the rhythm.',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 7),
                Text(
                  '$_completedActions of $_scheduledActions scheduled actions completed in this $_rangeTitle period.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: cs.tertiary),
                    const SizedBox(width: 6),
                    Text('$_perfectDays perfect days', style: theme.textTheme.labelLarge),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(ThemeData theme) {
    final cs = theme.colorScheme;
    final items = [
      ('Completed', '$_completedActions', Icons.check_circle_rounded, cs.secondary),
      ('Scheduled', '$_scheduledActions', Icons.event_available_rounded, cs.primary),
      ('Perfect days', '$_perfectDays', Icons.bolt_rounded, cs.tertiary),
      ('Habits', '${_habits.length}', Icons.grid_view_rounded, cs.secondary),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 94,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: item.$4.withValues(alpha: .16)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: item.$4.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(item.$3, color: item.$4, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                    Text(item.$1, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rhythmCard(ThemeData theme) {
    final cs = theme.colorScheme;
    final rhythm = _rhythm;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.secondary.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RHYTHM', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2, color: cs.secondary)),
                    const SizedBox(height: 4),
                    Text('Your consistency pulse', style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
              Icon(Icons.timeline_rounded, color: cs.secondary),
            ],
          ),
          const SizedBox(height: 18),
          if (rhythm.isEmpty)
            Text('Complete a habit to start your rhythm.', style: theme.textTheme.bodyMedium)
          else
            SizedBox(
              height: 118,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rhythm.map((item) {
                  final ratio = item.scheduled == 0 ? 0.0 : item.completed / item.scheduled;
                  final accent = ratio >= .8 ? cs.secondary : ratio > 0 ? cs.primary : cs.outline;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${(ratio * 100).round()}%', style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: .55))),
                          const SizedBox(height: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: math.max(8, 62 * ratio),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [accent.withValues(alpha: .35), accent],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: ratio > 0 ? [BoxShadow(color: accent.withValues(alpha: .18), blurRadius: 10)] : null,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(_dateLabel(item.date), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: .58))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'The rhythm uses real dates and completion percentages, so each period tells a different story.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _habitPulse(ThemeData theme) {
    final cs = theme.colorScheme;
    final ranked = [..._habits]
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HABIT PULSE', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2, color: cs.primary)),
          const SizedBox(height: 4),
          Text('Which habits are carrying you?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          if (ranked.isEmpty)
            Text('Create a habit to see its pulse here.', style: theme.textTheme.bodyMedium)
          else
            ...ranked.take(5).map((habit) {
              final accent = Color(habit.colorValue);
              final score = (habit.currentStreak / math.max(1, habit.bestStreak)).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: accent.withValues(alpha: .28)),
                      ),
                      child: HabitVisuals.icon(habit.icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.name, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: score,
                              backgroundColor: accent.withValues(alpha: .09),
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${habit.currentStreak}d', style: theme.textTheme.labelLarge?.copyWith(color: accent)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _insight(ThemeData theme) {
    final cs = theme.colorScheme;
    final percent = (_completionRate * 100).round();
    final text = _habits.isEmpty
        ? 'Create your first habit and your momentum story will appear here.'
        : percent >= 80
            ? 'Your consistency is strong. Keep protecting the rhythm you have built.'
            : percent >= 50
                ? 'You have a solid base. A little more consistency can move this into the next tier.'
                : 'Start small and protect one habit at a time. Consistency compounds.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.tertiary.withValues(alpha: .12), cs.primary.withValues(alpha: .08)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.tertiary.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: cs.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MOMENTUM INSIGHT', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.7, color: cs.tertiary)),
                const SizedBox(height: 6),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final List<Color> colors;

  const _NeonRingPainter({
    required this.progress,
    required this.track,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = track.withValues(alpha: .55);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress.clamp(0, 1);
    final path = Path()..addArc(rect, -math.pi / 2, sweep);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NeonRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
