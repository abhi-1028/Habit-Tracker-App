import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/habit_pause.dart';

List<Map<String, dynamic>> _decodeHabitMaps(String raw) {
  try {
    final decoded = jsonDecode(raw);
    dynamic data;
    if (decoded is Map && decoded['habits'] is List) {
      data = decoded['habits'];
    } else if (decoded is List) {
      data = decoded;
    } else {
      return <Map<String, dynamic>>[];
    }
    return (data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

/// Single local persistence layer for the app.
///
/// The app intentionally keeps persistence behind this service so screens and
/// state management never need to know how Hive stores data.
class LocalStorageService {
  static const String _boxName = 'habit_tracker_box';
  static const String _habitsKey = 'habits';
  static const String _profileNameKey = 'profile_name';
  static const String _avatarKey = 'profile_avatar';
  static const String _dailyGoalKey = 'daily_goal';
  static const String _themeModeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _compactModeKey = 'compact_mode';
  static const String _quoteDateKey = 'daily_quote_date';
  static const String _quoteTextKey = 'daily_quote_text';
  static const String _onboardingKey = 'profile_onboarding_complete';
  static const int _storageVersion = 4;
  static final ValueNotifier<String> profileNameNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> avatarNotifier = ValueNotifier<String>('✨');
  static final ValueNotifier<int> dailyGoalNotifier = ValueNotifier<int>(3);
  static final ValueNotifier<String> themeModeNotifier = ValueNotifier<String>('system');
  static final ValueNotifier<bool> notificationsNotifier = ValueNotifier<bool>(true);

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.openBox(_boxName);
      } catch (_) {
        // A restored/partially-written Hive box must not block a fresh app
        // launch. Recreate only this app box; all other app data is untouched.
        try {
          await Hive.deleteBoxFromDisk(_boxName);
        } catch (_) {}
        await Hive.openBox(_boxName);
      }
    }
    final savedName = loadProfileName();
    profileNameNotifier.value = savedName;
    avatarNotifier.value = loadAvatar();
    dailyGoalNotifier.value = loadDailyGoal();
    themeModeNotifier.value = loadThemeMode();
    notificationsNotifier.value = loadNotificationsEnabled();
  }

  static Box get _box => Hive.box(_boxName);

  // ---------------------------------------------------------------------------
  // HABITS
  // ---------------------------------------------------------------------------

  /// Saves the complete habit collection as one versioned JSON document.
  ///
  /// Version 2 adds pause persistence. The loader below also understands the
  /// previous unversioned list format, so existing installations are migrated
  /// automatically on the next save.
  static Future<void> saveHabits(List<Habit> habits) async {
    final payload = <String, dynamic>{
      'version': _storageVersion,
      'habits': habits.map(_habitToMap).toList(),
    };

    await _box.put(_habitsKey, jsonEncode(payload));
  }

  /// Loads the stored JSON payload without doing JSON decoding on the UI isolate.
  /// This keeps startup responsive when the completion history becomes large.
  static Future<List<Habit>> loadHabitsAsync() async {
    final storedData = _box.get(_habitsKey);
    if (storedData == null) return [];

    final raw = storedData is String ? storedData : jsonEncode(storedData);
    final maps = await compute(_decodeHabitMaps, raw);

    final habits = <Habit>[];
    for (final item in maps) {
      try {
        habits.add(_habitFromMap(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Keep valid habits even if one legacy record is malformed.
      }
    }
    return habits;
  }

  /// Loads habits while remaining backwards compatible with the previous
  /// storage format.
  static List<Habit> loadHabits() {
    final storedData = _box.get(_habitsKey);

    if (storedData == null) {
      return [];
    }

    try {
      dynamic decodedData;

      if (storedData is String) {
        decodedData = jsonDecode(storedData);
      } else {
        // Be tolerant of data written by the old HabitDatabase implementation.
        decodedData = storedData;
      }

      List<dynamic> habitData;

      if (decodedData is Map && decodedData['habits'] is List) {
        habitData = List<dynamic>.from(decodedData['habits'] as List);
      } else if (decodedData is List) {
        // Legacy unversioned format.
        habitData = List<dynamic>.from(decodedData);
      } else {
        return [];
      }

      final habits = <Habit>[];

      for (final item in habitData) {
        if (item is! Map) continue;

        try {
          habits.add(_habitFromMap(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Ignore one malformed habit instead of losing every valid habit.
        }
      }

      return habits;
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _habitToMap(Habit habit) {
    return {
      'id': habit.id,
      'name': habit.name,
      'type': habit.type.name,
      'target': habit.target,
      'unit': habit.unit,
      'icon': habit.icon,
      'colorValue': habit.colorValue,
      'todayProgress': habit.todayProgress,
      'scheduleType': habit.scheduleType.name,
      'scheduledWeekdays': List<int>.from(habit.scheduledWeekdays),
      'completions': habit.completions.map((completion) {
        return {
          'date': completion.date.toIso8601String(),
          'value': completion.value,
          'target': completion.target,
          'note': completion.note,
          'completedAt': completion.completedAt?.toIso8601String(),
        };
      }).toList(),
      'pauses': habit.pauses.map((pause) => pause.toMap()).toList(),
      'createdAt': habit.createdAt?.toIso8601String(),
      'isArchived': habit.isArchived,
      'scheduleHistory': habit.scheduleHistory.map((p) => p.toMap()).toList(),
    };
  }

  static Habit _habitFromMap(Map<String, dynamic> map) {
    final completions = <HabitCompletion>[];
    final completionsData = map['completions'];

    if (completionsData is List) {
      for (final item in completionsData) {
        if (item is! Map) continue;

        final completion = Map<String, dynamic>.from(item);
        final date = completion['date'];

        if (date is! String) continue;

        completions.add(
          HabitCompletion(
            date: DateTime.parse(date),
            value: _asInt(completion['value'], 0),
            target: _asInt(completion['target'], 1),
            note: completion['note'] as String?,
            completedAt: DateTime.tryParse(completion['completedAt'] as String? ?? ''),
          ),
        );
      }
    }

    final pauses = <HabitPause>[];
    final pausesData = map['pauses'];

    if (pausesData is List) {
      for (final item in pausesData) {
        if (item is! Map) continue;

        try {
          pauses.add(
            HabitPause.fromMap(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Ignore one malformed pause while preserving the habit.
        }
      }
    }

    final scheduledWeekdays = <int>[];
    final weekdaysData = map['scheduledWeekdays'];

    if (weekdaysData is List) {
      for (final day in weekdaysData) {
        final value = _asInt(day, 0);
        if (value >= 1 && value <= 7) {
          scheduledWeekdays.add(value);
        }
      }
    }

    final scheduleHistory = <HabitSchedulePeriod>[];
    final historyData = map['scheduleHistory'];
    if (historyData is List) {
      for (final item in historyData) {
        if (item is Map) {
          try { scheduleHistory.add(HabitSchedulePeriod.fromMap(Map<String, dynamic>.from(item))); } catch (_) {}
        }
      }
    }

    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final resolvedCreatedAt = createdAt ?? (() {
      final millis = int.tryParse(map['id'] as String? ?? '');
      return millis == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(millis);
    })();

    if (scheduleHistory.isEmpty) {
      scheduleHistory.add(HabitSchedulePeriod(
        startDate: resolvedCreatedAt,
        scheduleType: HabitScheduleType.values.firstWhere(
          (type) => type.name == map['scheduleType'],
          orElse: () => HabitScheduleType.daily,
        ),
        scheduledWeekdays: scheduledWeekdays,
      ));
    }

    return Habit(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Habit',
      type: HabitType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => HabitType.yesNo,
      ),
      target: _positiveInt(map['target'], 1),
      unit: map['unit'] as String? ?? '',
      icon: map['icon'] as String? ?? 'check',
      colorValue: _asInt(map['colorValue'], 0xFF4F46E5),
      scheduleType: HabitScheduleType.values.firstWhere(
        (type) => type.name == map['scheduleType'],
        orElse: () => HabitScheduleType.daily,
      ),
      scheduledWeekdays: scheduledWeekdays,
      todayProgress: _nonNegativeInt(map['todayProgress']),
      completions: completions,
      pauses: pauses,
      createdAt: resolvedCreatedAt,
      scheduleHistory: scheduleHistory,
      isArchived: map['isArchived'] == true,
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return fallback;
  }

  static int _positiveInt(dynamic value, int fallback) {
    final parsed = _asInt(value, fallback);
    return parsed < 1 ? 1 : parsed;
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = _asInt(value, 0);
    return parsed < 0 ? 0 : parsed;
  }

  // ---------------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------------

  static String loadProfileName() {
    return _box.get(_profileNameKey, defaultValue: '') as String;
  }


  static String loadAvatar() => _box.get(_avatarKey, defaultValue: '✨') as String;

  static Future<void> saveAvatar(String avatar) async {
    await _box.put(_avatarKey, avatar);
    avatarNotifier.value = avatar;
  }

  static int loadDailyGoal() {
    final value = _box.get(_dailyGoalKey, defaultValue: 3);
    return value is num ? value.clamp(1, 20).toInt() : 3;
  }

  static Future<void> saveDailyGoal(int goal) async {
    final safe = goal.clamp(1, 20);
    await _box.put(_dailyGoalKey, safe);
    dailyGoalNotifier.value = safe;
  }

  static String loadThemeMode() => _box.get(_themeModeKey, defaultValue: 'system') as String;

  static Future<void> saveThemeMode(String mode) async {
    await _box.put(_themeModeKey, mode);
    themeModeNotifier.value = mode;
  }

  static bool loadNotificationsEnabled() => _box.get(_notificationsKey, defaultValue: true) == true;

  static Future<void> saveNotificationsEnabled(bool enabled) async {
    await _box.put(_notificationsKey, enabled);
    notificationsNotifier.value = enabled;
  }


  static String loadDailyQuoteDate() => _box.get(_quoteDateKey, defaultValue: '') as String;

  static String loadDailyQuoteText() => _box.get(_quoteTextKey, defaultValue: '') as String;

  static Future<void> saveDailyQuote({required String date, required String text}) async {
    await _box.put(_quoteDateKey, date);
    await _box.put(_quoteTextKey, text);
  }

  static bool loadOnboardingComplete() => _box.get(_onboardingKey, defaultValue: false) == true;

  static Future<void> saveOnboardingComplete(bool value) async => _box.put(_onboardingKey, value);

  static bool loadCompactMode() =>
      _box.get(_compactModeKey, defaultValue: false) == true;

  static Future<void> saveCompactMode(bool enabled) async {
    await _box.put(_compactModeKey, enabled);
  }

  static Future<void> saveProfileName(String name) async {
    final trimmed = name.trim();
    await _box.put(_profileNameKey, trimmed);
    profileNameNotifier.value = trimmed;
  }
}
