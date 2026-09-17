import 'package:flutter/material.dart';

import '../../core/habit_visuals.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/profile_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HabitStore _habitStore = HabitStore.instance;

  String _profileName = '';
  String _avatar = '✨';
  bool _quoteRevealed = false;
  late String _dailyQuote;

  @override
  void initState() {
    super.initState();

    _profileName = LocalStorageService.loadProfileName();
    _avatar = LocalStorageService.loadAvatar();
    _dailyQuote = _quoteForToday();
    _quoteRevealed = LocalStorageService.loadDailyQuoteDate() == _dateKey(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_quoteRevealed) _showDailyScratchDialog();
    });

    LocalStorageService.profileNameNotifier.addListener(_onProfileNameChanged);
    LocalStorageService.avatarNotifier.addListener(_onAvatarChanged);
    _habitStore.addListener(_onHabitsChanged);
  }

  @override
  void dispose() {
    _habitStore.removeListener(_onHabitsChanged);
    LocalStorageService.profileNameNotifier.removeListener(_onProfileNameChanged);
    LocalStorageService.avatarNotifier.removeListener(_onAvatarChanged);
    super.dispose();
  }

  void _onHabitsChanged() {
    if (mounted) setState(() {});
  }

  void _onAvatarChanged() { if (mounted) setState(() => _avatar = LocalStorageService.avatarNotifier.value); }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String _quoteForToday() {
    const quotes = [
      'Small steps, repeated daily, become remarkable change.',
      'You do not need a perfect day. You need a consistent one.',
      'Make today a vote for the person you want to become.',
      'Discipline gets easier when you keep showing up.',
      'Progress loves patience. Keep going.',
      'Your future self is built by today’s tiny choices.',
      'One completed habit is still a win. Stack another.',
    ];
    final d = DateTime.now();
    final index = (d.year * 1000 + d.month * 31 + d.day) % quotes.length;
    return quotes[index];
  }

  Future<void> _revealQuote() async {
    await LocalStorageService.saveDailyQuote(date: _dateKey(DateTime.now()), text: _dailyQuote);
    if (mounted) setState(() => _quoteRevealed = true);
  }

  void _onProfileNameChanged() {
    if (mounted) {
      setState(() {
        _profileName = LocalStorageService.profileNameNotifier.value;
      });
    }
  }

  Future<void> _increaseProgress(Habit habit) async {
    await _habitStore.increaseProgress(habit.id);
    if (!mounted) return;
    final updated = _habitStore.habits.firstWhere((h) => h.id == habit.id);
    if (updated.isCompleted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Habit completed'),
          action: SnackBarAction(
            label: 'Add note',
            onPressed: () => _showNoteDialog(updated),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) messenger.hideCurrentSnackBar();
      });
    }
  }

  Future<void> _decreaseProgress(Habit habit) async {
    final before = habit.completionForDate(DateTime.now());
    await _habitStore.decreaseProgress(habit.id);
    if (!mounted) return;
    final after = _habitStore.habits.firstWhere((h) => h.id == habit.id).completionForDate(DateTime.now());
    if (before?.isCompleted == true && after?.isCompleted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This completion is locked after 10 minutes.')),
      );
    }
  }

  Future<void> _showNoteDialog(Habit habit) async {
    final completion = habit.completionForDate(DateTime.now());
    if (completion == null) return;

    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _HabitNoteDialog(
        initialNote: completion.note ?? '',
      ),
    );

    if (!mounted || result == null) return;

    final saved = await _habitStore.updateNote(
      habit.id,
      DateTime.now(),
      result,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Note saved.' : 'Unable to save this note.'),
      ),
    );
  }

  // ------------------------------------------------------------
  // TODAY'S HABITS
  // ------------------------------------------------------------

  List<Habit> _getTodayHabits() {
    final today = DateTime.now();

    return _habitStore.habits.where((habit) {
      return !habit.isArchived && habit.isScheduledForDate(today);
    }).toList();
  }

  // ------------------------------------------------------------
  // TODAY'S ACTUAL PROGRESS
  // ------------------------------------------------------------

  double _getHabitProgress(Habit habit) {
    // Measurable habit:
    // progress is based on today's value versus target.
    if (habit.type == HabitType.measurable) {
      if (habit.target <= 0) {
        return 0.0;
      }

      return (habit.todayProgress / habit.target)
          .clamp(0.0, 1.0);
    }

    // Normal habit:
    // either 0% or 100%.
    return habit.isCompleted ? 1.0 : 0.0;
  }

  double _getOverallProgress(List<Habit> habits) {
    if (habits.isEmpty) {
      return 0.0;
    }

    double totalProgress = 0.0;

    for (final habit in habits) {
      totalProgress += _getHabitProgress(habit);
    }

    return totalProgress / habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final todayHabits = _getTodayHabits();

    final completedCount =
        todayHabits.where((habit) => habit.isCompleted).length;

    final totalCount = todayHabits.length;

    // IMPORTANT:
    // This now represents actual progress toward every
    // habit's target, not just whether the habit is completed.
    final progress = _getOverallProgress(todayHabits);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(theme),

              const SizedBox(height: 14),
              _buildDailyQuoteCard(theme),

              const SizedBox(height: 24),

              _buildProgressCard(
                theme,
                completedCount,
                totalCount,
                progress,
              ),

              const SizedBox(height: 28),

              _buildSectionTitle("Today's Habits"),

              const SizedBox(height: 12),

              if (todayHabits.isEmpty)
                _buildEmptyHabitsCard(theme)
              else
                ...todayHabits.map(
                      (habit) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
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
                todayHabits,
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

  // ------------------------------------------------------------
  // WELCOME
  // ------------------------------------------------------------

  Widget _buildWelcomeSection(ThemeData theme) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Row(children: [
      _buildAvatar(theme, 58),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$greeting, ${_profileName.isEmpty ? 'there' : _profileName}! 👋', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('One good choice at a time.', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ])),
    ]);
  }

  Widget _buildAvatar(ThemeData theme, double size) => ProfileAvatar(value: _avatar, size: size);

  Widget _buildDailyQuoteCard(ThemeData theme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: Card(
        key: ValueKey(_quoteRevealed),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: .12)), child: Icon(Icons.format_quote_rounded, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("TODAY'S REVEAL", style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              Text(_dailyQuote, style: theme.textTheme.titleMedium?.copyWith(height: 1.35, fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(width: 8),
            Icon(Icons.verified_rounded, color: theme.colorScheme.primary),
          ]),
        ),
      ),
    );
  }

  Future<void> _showDailyScratchDialog() async {
    if (!mounted || _quoteRevealed) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Daily quote',
      barrierColor: Colors.black.withValues(alpha: .72),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, _, __) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: _DailyScratchCard(
              quote: _dailyQuote,
              onRevealed: () async {
                await _revealQuote();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ------------------------------------------------------------
  // TODAY'S PROGRESS
  // ------------------------------------------------------------

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
              width: 112,
              height: 112,
              child: CustomPaint(
                painter: _HomeNeonRingPainter(
                  progress: progress,
                  track: theme.colorScheme.outlineVariant,
                  colors: const [
                    Color(0xFF27E7FF),
                    Color(0xFFFF4FD8),
                    Color(0xFFB6FF3B),
                    Color(0xFFFF9F43),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$percentage%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Progress",
                    style:
                    theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '$completedCount of $totalCount '
                        'habits completed',
                    style:
                    theme.textTheme.bodyMedium?.copyWith(
                      color:
                      theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Progress updates as you work toward each target.',
                    style:
                    theme.textTheme.bodySmall?.copyWith(
                      color:
                      theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
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

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY HABITS
  // ------------------------------------------------------------

  Widget _buildEmptyHabitsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 12),

            Text(
              'No habits scheduled for today',
              textAlign: TextAlign.center,
              style:
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Enjoy the day or create a habit for today.',
              textAlign: TextAlign.center,
              style:
              theme.textTheme.bodyMedium?.copyWith(
                color:
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForHabit(Habit habit) {
    const icons = <String, IconData>{
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

  // ------------------------------------------------------------
  // HABIT CARD
  // ------------------------------------------------------------

  Widget _buildHabitCard(
      ThemeData theme,
      Habit habit,
      ) {
    final isMeasurable =
        habit.type == HabitType.measurable;

    final isCompleted = habit.isCompleted;

    final habitProgress = _getHabitProgress(habit);

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
                color: Color(habit.colorValue).withValues(
                  alpha: isCompleted ? 0.20 : 0.12,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: HabitVisuals.icon(
                  habit.icon,
                  size: 24,
                  color: Color(habit.colorValue),
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
                      value: habitProgress,
                      minHeight: 5,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${(habitProgress * 100).round()}% complete',
                      style:
                      theme.textTheme.labelSmall?.copyWith(
                        color:
                        theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
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
                        ? () =>
                        _decreaseProgress(habit)
                        : null,
                    icon: const Icon(
                      Icons.remove,
                    ),
                  ),

                  IconButton(
                    onPressed: habit.isCompleted
                        ? null
                        : () =>
                        _increaseProgress(habit),
                    icon: const Icon(
                      Icons.add,
                    ),
                  ),
                ],
              )
            else
              IconButton(
                onPressed: isCompleted
                    ? () =>
                    _decreaseProgress(habit)
                    : () =>
                    _increaseProgress(habit),
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

  // ------------------------------------------------------------
  // STREAK HIGHLIGHTS
  // ------------------------------------------------------------

  Widget _buildStreakHighlights(ThemeData theme, List<Habit> todayHabits) {
    final ranked = [...todayHabits]..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    final top = ranked.take(3).toList();
    if (top.isEmpty) {
      return Card(child: Padding(padding: const EdgeInsets.all(18), child: Text('Complete a habit today and your momentum will appear here.', style: theme.textTheme.bodyLarge)));
    }
    return Row(children: [
      for (var i = 0; i < top.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: _streakTile(theme, top[i], i)),
      ],
    ]);
  }

  Widget _streakTile(ThemeData theme, Habit habit, int rank) {
    final accent = [
      const Color(0xFFFF4FD8),
      const Color(0xFF27E7FF),
      const Color(0xFFB6FF3B),
    ][rank];
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: .09),
        border: Border.all(color: accent.withValues(alpha: .25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .16)), child: Center(child: HabitVisuals.icon(habit.icon, size: 18, color: accent))),
          const SizedBox(width: 8),
          Text('#${rank + 1}', style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 14),
        Text('${habit.currentStreak} days', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
      ]),
    );
  }

  // ------------------------------------------------------------
  // MOTIVATIONAL INSIGHT
  // ------------------------------------------------------------

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
              style: TextStyle(
                fontSize: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                'Every small step counts. Start with one '
                    'habit and keep going!',
                style:
                theme.textTheme.bodyLarge?.copyWith(
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


class _HomeNeonRingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final List<Color> colors;

  const _HomeNeonRingPainter({
    required this.progress,
    required this.track,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = track.withValues(alpha: .55);
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final sweep = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);
    final path = Path()..addArc(rect, -3.141592653589793 / 2, sweep);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -3.141592653589793 / 2,
        endAngle: -3.141592653589793 / 2 + 2 * 3.141592653589793,
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(path, glow);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -3.141592653589793 / 2,
        endAngle: -3.141592653589793 / 2 + 2 * 3.141592653589793,
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeNeonRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}

class _HabitNoteDialog extends StatefulWidget {
  final String initialNote;

  const _HabitNoteDialog({required this.initialNote});

  @override
  State<_HabitNoteDialog> createState() => _HabitNoteDialogState();
}

class _HabitNoteDialogState extends State<_HabitNoteDialog> {
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
      title: const Text('Add a note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          hintText: 'Write a note about this completion',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.initialNote.trim().isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Delete'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save note'),
        ),
      ],
    );
  }
}


class _DailyScratchCard extends StatefulWidget {
  final String quote;
  final Future<void> Function() onRevealed;
  const _DailyScratchCard({required this.quote, required this.onRevealed});
  @override State<_DailyScratchCard> createState() => _DailyScratchCardState();
}

class _DailyScratchCardState extends State<_DailyScratchCard> {
  final List<Offset> _scratches = [];
  bool _revealing = false;

  void _scratch(Offset point) {
    if (_revealing) return;
    setState(() => _scratches.add(point));
    if (_scratches.length >= 42) {
      _revealing = true;
      widget.onRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: theme.colorScheme.surface,
          boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .28), blurRadius: 45, spreadRadius: 4)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: .12)), child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DAILY REVEAL', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.3, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              const SizedBox(height: 2), Text('A little motivation for today', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            ])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), child: SizedBox(
            height: 250,
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _scratch(d.localPosition),
                onPanUpdate: (d) => _scratch(d.localPosition),
                child: Stack(children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17132B), Color(0xFF33225C), Color(0xFF101A2C)])),
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('✨', style: TextStyle(fontSize: 42)),
                      const SizedBox(height: 12),
                      Text(widget.quote, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.35)),
                      const SizedBox(height: 12),
                      Text('Scratch the silver layer to reveal', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  Positioned.fill(child: CustomPaint(painter: _ScratchLayerPainter(points: _scratches, primary: theme.colorScheme.primary))),
                ]),
              );
            }),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [
            Icon(Icons.touch_app_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Scratch anywhere on the card. Your revealed quote stays at the top of Home today.', style: theme.textTheme.bodySmall)),
          ])),
        ]),
      ),
    );
  }
}

class _ScratchLayerPainter extends CustomPainter {
  final List<Offset> points;
  final Color primary;
  _ScratchLayerPainter({required this.points, required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    final base = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE9E9EF), Color(0xFF8C8E99), Color(0xFFF7F7FA), Color(0xFF9A9CA8)]).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)), base);

    final shine = Paint()..color = primary.withValues(alpha: .12)..strokeWidth = 1.4;
    for (double x = -size.height; x < size.width + size.height; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), shine);
    }

    final textPainter = TextPainter(text: const TextSpan(text: 'SCRATCH  •  REVEAL  •  SCRATCH', style: TextStyle(color: Color(0xFF343640), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.6)), textDirection: TextDirection.ltr)..layout(maxWidth: size.width - 40);
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height / 2 - textPainter.height / 2));

    final eraser = Paint()..blendMode = BlendMode.clear..style = PaintingStyle.fill;
    for (final point in points) canvas.drawCircle(point, 24, eraser);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScratchLayerPainter oldDelegate) => oldDelegate.points.length != points.length;
}
