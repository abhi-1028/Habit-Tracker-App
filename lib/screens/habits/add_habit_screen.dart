import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../core/habit_visuals.dart';
import '../../services/habit_store.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();

  HabitType _selectedType = HabitType.yesNo;

  HabitScheduleType _selectedScheduleType =
      HabitScheduleType.daily;

  final Set<int> _selectedWeekdays = {};

  bool _isSaving = false;
  String _selectedIcon = 'check';
  int _selectedColor = 0xFF27E7FF;

  final List<Map<String, dynamic>> _weekdays = const [
    {
      'day': 1,
      'name': 'Monday',
      'shortName': 'Mon',
    },
    {
      'day': 2,
      'name': 'Tuesday',
      'shortName': 'Tue',
    },
    {
      'day': 3,
      'name': 'Wednesday',
      'shortName': 'Wed',
    },
    {
      'day': 4,
      'name': 'Thursday',
      'shortName': 'Thu',
    },
    {
      'day': 5,
      'name': 'Friday',
      'shortName': 'Fri',
    },
    {
      'day': 6,
      'name': 'Saturday',
      'shortName': 'Sat',
    },
    {
      'day': 7,
      'name': 'Sunday',
      'shortName': 'Sun',
    },
  ];

  Future<void> _pickCustomIcon() async {
    final initial = HabitVisuals.isCustom(_selectedIcon)
        ? HabitVisuals.decodeCustom(_selectedIcon)
        : '';
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final controller = TextEditingController(text: initial);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Custom icon', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Enter one emoji or symbol for this habit.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 38),
                maxLines: 1,
                decoration: const InputDecoration(hintText: '😊', prefixIcon: Icon(Icons.auto_awesome_rounded)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    final safe = String.fromCharCodes(text.runes.take(4));
                    Navigator.of(sheetContext).pop(safe);
                  },
                  child: const Text('Use this icon'),
                ),
              ),
              const SizedBox(height: 6),
              Center(child: TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Cancel'))),
            ],
          ),
        );
      },
    );
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _selectedIcon = HabitVisuals.encodeCustom(value));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveHabit() async {
    if (_isSaving) {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a habit name.'),
        ),
      );
      return;
    }

    final targetText = _targetController.text.trim();

    final target = int.tryParse(targetText);

    if (_selectedType == HabitType.measurable) {
      if (target == null || target <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter a valid target greater than 0.',
            ),
          ),
        );
        return;
      }
    }

    final unit = _unitController.text.trim();

    if (_selectedType == HabitType.measurable &&
        unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a unit, such as glasses or minutes.',
          ),
        ),
      );
      return;
    }

    // Validate specific-day schedule.
    if (_selectedScheduleType ==
        HabitScheduleType.specificDays &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one day.',
          ),
        ),
      );
      return;
    }

    final selectedDays = _selectedWeekdays.toList()..sort();
    final normalizedSchedule = selectedDays.length == 7
        ? HabitScheduleType.daily
        : _selectedScheduleType;
    final scheduledWeekdays = normalizedSchedule == HabitScheduleType.specificDays
        ? selectedDays
        : <int>[];

    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: _selectedType,
      target: _selectedType == HabitType.measurable
          ? target!
          : 1,
      unit: _selectedType == HabitType.measurable
          ? unit
          : '',
      scheduleType: normalizedSchedule,
      scheduledWeekdays: scheduledWeekdays,
      icon: _selectedIcon,
      colorValue: _selectedColor,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isSaving = true;
    });

    bool wasAdded = false;
    try {
      wasAdded = await HabitStore.instance.addHabit(habit);
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this habit. Please try again.')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!wasAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have a habit named "$name".',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      return;
    }

    Navigator.pop(context, habit);
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Habit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new habit',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Set up your habit and choose when you want to follow it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 28),

            // -----------------------------
            // HABIT NAME
            // -----------------------------

            Text(
              'Habit name',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _nameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              enableSuggestions: true,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Example: Drink Water',
                prefixIcon: Icon(Icons.edit_rounded),
                counterText: '',
              ),
            ),

            const SizedBox(height: 24),

            HabitVisuals.picker(
              context: context,
              selectedIcon: _selectedIcon,
              selectedColor: _selectedColor,
              onIconChanged: (value) => setState(() => _selectedIcon = value),
              onColorChanged: (value) => setState(() => _selectedColor = value),
              onCustom: _pickCustomIcon,
            ),

            const SizedBox(height: 24),

            // -----------------------------
            // HABIT TYPE
            // -----------------------------

            Text(
              'Habit type',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            SegmentedButton<HabitType>(
              segments: const [
                ButtonSegment<HabitType>(
                  value: HabitType.yesNo,
                  label: Text('Yes / No'),
                  icon: Icon(
                    Icons.check_circle_outline,
                  ),
                ),
                ButtonSegment<HabitType>(
                  value: HabitType.measurable,
                  label: Text('Measurable'),
                  icon: Icon(
                    Icons.track_changes,
                  ),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedType = selection.first;

                  if (_selectedType == HabitType.yesNo) {
                    _targetController.clear();
                    _unitController.clear();
                  }
                });
              },
            ),

            // -----------------------------
            // MEASURABLE OPTIONS
            // -----------------------------

            if (_selectedType == HabitType.measurable) ...[
              const SizedBox(height: 24),

              Text(
                'Daily target',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Example: 8',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Unit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _unitController,
                decoration: const InputDecoration(
                  hintText: 'Example: glasses',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // -----------------------------
            // SCHEDULE
            // -----------------------------

            Text(
              'Schedule',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            SegmentedButton<HabitScheduleType>(
              segments: const [
                ButtonSegment<HabitScheduleType>(
                  value: HabitScheduleType.daily,
                  label: Text('Every day'),
                  icon: Icon(
                    Icons.calendar_today,
                  ),
                ),
                ButtonSegment<HabitScheduleType>(
                  value: HabitScheduleType.specificDays,
                  label: Text('Specific days'),
                  icon: Icon(
                    Icons.date_range,
                  ),
                ),
              ],
              selected: {_selectedScheduleType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedScheduleType =
                      selection.first;
                });
              },
            ),

            // -----------------------------
            // SPECIFIC DAYS
            // -----------------------------

            if (_selectedScheduleType ==
                HabitScheduleType.specificDays) ...[
              const SizedBox(height: 20),

              Text(
                'Select days',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Choose the days you want to follow this habit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekdays.map((weekday) {
                  final day =
                  weekday['day'] as int;

                  final name =
                  weekday['name'] as String;

                  final shortName =
                  weekday['shortName'] as String;

                  final isSelected =
                  _selectedWeekdays.contains(day);

                  return FilterChip(
                    label: Text(shortName),
                    selected: isSelected,
                    tooltip: name,
                    onSelected: (_) {
                      _toggleWeekday(day);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 36),

            // -----------------------------
            // CREATE BUTTON
            // -----------------------------

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                _isSaving ? null : _saveHabit,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.check),
                label: Text(
                  _isSaving
                      ? 'Creating...'
                      : 'Create Habit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}