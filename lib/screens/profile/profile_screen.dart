import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/habit.dart';
import '../../services/habit_store.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final HabitStore _habitStore = HabitStore.instance;
  String _profileName = '';
  String _avatar = '✨';
  int _dailyGoal = 3;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _profileName = LocalStorageService.loadProfileName();
    _avatar = LocalStorageService.loadAvatar();
    _dailyGoal = LocalStorageService.loadDailyGoal();
    _notifications = LocalStorageService.loadNotificationsEnabled();
    _habitStore.addListener(_refresh);
    LocalStorageService.avatarNotifier.addListener(_refresh);
    LocalStorageService.themeModeNotifier.addListener(_refresh);
  }

  @override
  void dispose() {
    _habitStore.removeListener(_refresh);
    LocalStorageService.avatarNotifier.removeListener(_refresh);
    LocalStorageService.themeModeNotifier.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() { if (mounted) setState(() { _avatar = LocalStorageService.avatarNotifier.value; }); }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfileScreen(
      currentName: _profileName,
      onNameChanged: (value) async {
        final name = value.trim();
        if (name.isEmpty) return;
        await LocalStorageService.saveProfileName(name);
        if (mounted) setState(() => _profileName = name);
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habits = _habitStore.habits;
    final totalHabits = habits.length;
    final bestStreak = habits.isEmpty ? 0 : habits.map((h) => h.bestStreak).reduce((a,b) => a > b ? a : b);
    final completionDays = _getCompletionDays(habits).length;
    final completedEntries = _getTotalCompletedEntries(habits);
    final unlocked = _getUnlockedAchievementCount(habits);
    const totalAchievements = 12;
    final completionRate = _completionRate(habits);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildProfileHeader(theme),
            const SizedBox(height: 22),
            _buildJourneyStats(theme, totalHabits, bestStreak, completionDays, unlocked),
            const SizedBox(height: 24),
            _sectionTitle(theme, 'Your Progress', 'A quick look at your consistency.'),
            const SizedBox(height: 12),
            _buildProgressDashboard(theme, completedEntries, completionDays, completionRate, bestStreak),
            const SizedBox(height: 24),
            _sectionTitle(theme, 'Achievements', '$unlocked of $totalAchievements unlocked'),
            const SizedBox(height: 12),
            _buildAchievementCard(theme, unlocked, totalAchievements),
            const SizedBox(height: 24),
            _buildMotivationCard(theme),
            const SizedBox(height: 24),
            _sectionTitle(theme, 'Personalize', 'Make Habit Tracker feel like yours.'),
            const SizedBox(height: 12),
            _buildPreferences(theme),
          ]),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
    const SizedBox(height: 3),
    Text(subtitle, style: theme.textTheme.bodySmall),
  ]);

  Widget _buildProfileHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer]),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .28)),
        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .10), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.surface,
              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .22), blurRadius: 18)]),
            child: ProfileAvatar(value: _avatar, size: 104),
          ),
          Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(onTap: _chooseAvatar, customBorder: const CircleBorder(),
              child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.edit_rounded, size: 19, color: theme.colorScheme.onPrimary))),
          ),
        ]),
        const SizedBox(height: 14),
        Text(_profileName.isEmpty ? 'Habit Builder' : _profileName,
          textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Building better habits, one day at a time.', textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _openEditProfile, icon: const Icon(Icons.manage_accounts_rounded), label: const Text('Edit profile')),
      ]),
    );
  }

  Widget _buildJourneyStats(ThemeData theme, int habits, int streak, int days, int achievements) {
    final items = [
      ('HABITS', '$habits', Icons.checklist_rounded, theme.colorScheme.primary),
      ('BEST STREAK', '$streak', Icons.local_fire_department_rounded, const Color(0xFFFF4FD8)),
      ('ACTIVE DAYS', '$days', Icons.calendar_month_rounded, const Color(0xFFB6FF3B)),
      ('ACHIEVEMENTS', '$achievements', Icons.emoji_events_rounded, const Color(0xFFFF9F43)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('YOUR JOURNEY', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(children: [for (var i = 0; i < 2; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == 0 ? 8 : 0), child: _journeyTile(theme, items[i])))]),
        const SizedBox(height: 8),
        Row(children: [for (var i = 2; i < 4; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == 2 ? 8 : 0), child: _journeyTile(theme, items[i])))]),
      ]),
    );
  }

  Widget _journeyTile(ThemeData theme, (String,String,IconData,Color) item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: item.$4.withValues(alpha: .09), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.$4.withValues(alpha: .25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(item.$3, color: item.$4, size: 24),
        const SizedBox(height: 12),
        Text(item.$2, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        Text(item.$1, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: .8, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildProgressDashboard(ThemeData theme, int entries, int days, double rate, int streak) {
    final percent = (rate * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(26), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 94, height: 94, child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: rate, strokeWidth: 9, backgroundColor: theme.colorScheme.outlineVariant, color: theme.colorScheme.primary),
            Center(child: Text('$percent%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          ])),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consistency score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(rate >= .8 ? 'Excellent momentum!' : rate >= .5 ? 'You are building momentum.' : 'Every completed habit counts.', style: theme.textTheme.bodyMedium),
          ])),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _miniMetric(theme, Icons.done_all_rounded, '$entries', 'Completed')),
          const SizedBox(width: 10),
          Expanded(child: _miniMetric(theme, Icons.today_rounded, '$days', 'Active days')),
          const SizedBox(width: 10),
          Expanded(child: _miniMetric(theme, Icons.local_fire_department_rounded, '$streak', 'Best streak')),
        ]),
      ]),
    );
  }

  Widget _miniMetric(ThemeData theme, IconData icon, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [Icon(icon, size: 20, color: theme.colorScheme.primary), const SizedBox(height: 4), Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelSmall)]),
  );

  Widget _buildAchievementCard(ThemeData theme, int unlocked, int total) {
    final progress = total == 0 ? 0.0 : (unlocked / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: theme.colorScheme.surfaceContainer, border: Border.all(color: const Color(0xFFFFD166).withValues(alpha: .35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFD166).withValues(alpha: .15)), child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF9F43))), const SizedBox(width: 12), Expanded(child: Text(unlocked == total ? 'All achievements unlocked!' : 'Keep your momentum going', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)))]),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 9)),
        const SizedBox(height: 8),
        Text('$unlocked / $total unlocked', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildMotivationCard(ThemeData theme) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(colors: [theme.colorScheme.primary.withValues(alpha: .12), theme.colorScheme.secondary.withValues(alpha: .10)]), border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .18))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('⚡', style: TextStyle(fontSize: 28)), const SizedBox(width: 12), Expanded(child: Text('Consistency beats perfection. Keep showing up and let small wins compound.', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35)))]),
  );

  Widget _buildPreferences(ThemeData theme) {
    final labels = {'dark':'Midnight Neon','light':'Neon Daylight','system':'System default','ocean':'Cyber Ocean','forest':'Neon Forest','sunset':'Electric Sunset','lavender':'Ultraviolet'};
    final themeLabel = labels[LocalStorageService.themeModeNotifier.value] ?? 'System default';
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(children: [
        _settingTile(theme, Icons.face_retouching_natural_rounded, 'Avatar', _avatar.startsWith('image:') ? 'Custom photo' : 'Custom illustrated avatar', _chooseAvatar),
        const Divider(height: 1),
        _settingTile(theme, Icons.flag_rounded, 'Daily goal', '$_dailyGoal habits per day', _chooseDailyGoal),
        const Divider(height: 1),
        _settingTile(theme, Icons.palette_rounded, 'Theme', themeLabel, _chooseTheme),
        const Divider(height: 1),
        SwitchListTile.adaptive(
          secondary: Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
          title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Reminders and meaningful habit updates'), value: _notifications,
          onChanged: (value) async { if (value) { await NotificationService.requestPermissions(); await NotificationService.scheduleHabitReminders(_habitStore.habits); } else { await NotificationService.cancelAll(); } await LocalStorageService.saveNotificationsEnabled(value); if (mounted) setState(() => _notifications = value); },
        ),
      ]),
    );
  }

  Widget _settingTile(ThemeData theme, IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7), leading: Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: .10)), child: Icon(icon, color: theme.colorScheme.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap,
  );

  Future<void> _chooseAvatar() async {
    final choice = await showModalBottomSheet<String>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => _AvatarStudioSheet(initial: _avatar));
    if (choice == null || !mounted) return;
    await LocalStorageService.saveAvatar(choice);
    setState(() => _avatar = choice);
  }

  Future<void> _chooseDailyGoal() async {
    final value = await showDialog<int>(context: context, builder: (context) => SimpleDialog(title: const Text('Daily goal'), children: [for (var goal=1; goal<=10; goal++) SimpleDialogOption(onPressed: () => Navigator.pop(context, goal), child: Row(children: [Icon(goal == _dailyGoal ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: goal == _dailyGoal ? Theme.of(context).colorScheme.primary : null), const SizedBox(width: 12), Text('$goal habit${goal == 1 ? '' : 's'} per day')]))]));
    if (value != null) { await LocalStorageService.saveDailyGoal(value); if (mounted) setState(() => _dailyGoal = value); }
  }

  Future<void> _chooseTheme() async {
    final current = LocalStorageService.themeModeNotifier.value;
    final items = const [('system','System default'),('light','Neon Daylight'),('dark','Midnight Neon'),('ocean','Cyber Ocean'),('forest','Neon Forest'),('sunset','Electric Sunset'),('lavender','Ultraviolet')];
    final value = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 8, 16, 18), children: [Padding(padding: const EdgeInsets.all(8), child: Text('Choose your vibe', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), for (final item in items) RadioListTile<String>(value: item.$1, groupValue: current, title: Text(item.$2), secondary: Icon(Icons.palette_rounded, color: item.$1 == current ? Theme.of(context).colorScheme.primary : null), onChanged: (v) => Navigator.pop(context, v))])));
    if (value != null) await LocalStorageService.saveThemeMode(value);
  }

  double _completionRate(List<Habit> habits) {
    var scheduled = 0, completed = 0;
    for (final h in habits) { for (final c in h.completions) { if (h.isScheduledForDate(c.date)) { scheduled++; if (c.isCompleted) completed++; } } }
    return scheduled == 0 ? 0 : (completed / scheduled).clamp(0.0, 1.0);
  }

  int _getTotalCompletedEntries(List<Habit> habits) => habits.fold(0, (sum, h) => sum + h.completions.where((c) => h.isScheduledForDate(c.date) && c.isCompleted).length);

  Set<DateTime> _getCompletionDays(List<Habit> habits) {
    final dates = <DateTime>{};
    for (final h in habits) for (final c in h.completions) if (h.isScheduledForDate(c.date) && c.isCompleted) dates.add(DateTime(c.date.year, c.date.month, c.date.day));
    return dates;
  }

  int _getUnlockedAchievementCount(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    final hasAny = habits.any((h) => h.completions.any((c) => h.isScheduledForDate(c.date) && c.isCompleted));
    final best = habits.map((h) => h.bestStreak).reduce((a,b) => a > b ? a : b);
    final days = _getCompletionDays(habits).length;
    var unlocked = 0;
    if (hasAny) unlocked++;
    if (habits.length >= 3) unlocked++;
    if (habits.length >= 5) unlocked++;
    if (best >= 3) unlocked++;
    if (best >= 7) unlocked++;
    if (best >= 14) unlocked++;
    if (best >= 30) unlocked++;
    if (_hasPerfectDay(habits)) unlocked++;
    if (days >= 10) unlocked++;
    if (days >= 30) unlocked++;
    if (_completionRate(habits) >= .75) unlocked++;
    if (_completionRate(habits) >= .95) unlocked++;
    return unlocked.clamp(0, 12);
  }

  bool _hasPerfectDay(List<Habit> habits) {
    final dates = _getCompletionDays(habits);
    for (final date in dates) {
      final scheduled = habits.where((h) => h.isScheduledForDate(date));
      if (scheduled.isNotEmpty && scheduled.every((h) => h.completionForDate(date)?.isCompleted == true)) return true;
    }
    return false;
  }
}

class _AvatarStudioSheet extends StatefulWidget {
  final String initial;
  const _AvatarStudioSheet({required this.initial});
  @override State<_AvatarStudioSheet> createState() => _AvatarStudioSheetState();
}

class _AvatarStudioSheetState extends State<_AvatarStudioSheet> {
  late ProfileAvatarData data;
  @override void initState() { super.initState(); data = ProfileAvatarData.decode(widget.initial) ?? const ProfileAvatarData(); }
  void _update({int? skin, int? hair, int? shirt, int? eyes, int? accessory}) => setState(() => data = ProfileAvatarData(skin: skin ?? data.skin, hair: hair ?? data.hair, shirt: shirt ?? data.shirt, eyes: eyes ?? data.eyes, accessory: accessory ?? data.accessory));

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), child: Column(children: [
      Text('Avatar Studio', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4), Text('Create your own illustrated identity. Your choices stay on this device.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 18),
      Container(width: 150, height: 150, padding: const EdgeInsets.all(8), decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.surfaceContainerHighest, boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .18), blurRadius: 30)]), child: ProfileAvatar(value: data.encode(), size: 134)),
      const SizedBox(height: 18),
      Align(alignment: Alignment.centerLeft, child: Text('Quick presets', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
      const SizedBox(height: 10),
      SizedBox(height: 92, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: ProfileAvatarData.presets.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (context, index) {
        final preset = ProfileAvatarData.presets[index];
        final selected = data.encode() == preset.value.encode();
        return InkWell(onTap: () => setState(() => data = preset.value), borderRadius: BorderRadius.circular(18), child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 82, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: selected ? theme.colorScheme.primary.withValues(alpha: .12) : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: selected ? 2 : 1)), child: Column(children: [ProfileAvatar(value: preset.value.encode(), size: 52), const SizedBox(height: 4), Text(preset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))])));
      })),
      const SizedBox(height: 18),
      _choiceRow('Skin tone', ProfileAvatarData.skinsForUi, data.skin, (v) => _update(skin: v)),
      _choiceRow('Hair', ProfileAvatarData.hairsForUi, data.hair, (v) => _update(hair: v)),
      _choiceRow('Outfit', ProfileAvatarData.shirtsForUi, data.shirt, (v) => _update(shirt: v)),
      _choiceRow('Eyes', const ['Classic','Glasses'], data.eyes, (v) => _update(eyes: v)),
      _choiceRow('Accessory', const ['None','Star','Cap'], data.accessory, (v) => _update(accessory: v)),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(context, data.encode()), icon: const Icon(Icons.check_rounded), label: const Text('Use this avatar'))),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _choosePhoto, icon: const Icon(Icons.photo_library_outlined), label: const Text('Use a private gallery photo')),
    ])));
  }

  Widget _choiceRow(String title, List<String> options, int selected, ValueChanged<int> onChanged) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 7), Wrap(spacing: 7, runSpacing: 7, children: [for (var i=0; i<options.length; i++) ChoiceChip(label: Text(options[i]), selected: i == selected, onSelected: (_) => onChanged(i))]) ]));

  Future<void> _choosePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 900);
    if (picked == null || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${dir.path}/profile');
    await avatarDir.create(recursive: true);
    final target = File('${avatarDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(target.path);
    if (mounted) Navigator.pop(context, 'image:${target.path}');
  }
}

