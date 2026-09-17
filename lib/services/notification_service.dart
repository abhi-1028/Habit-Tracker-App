import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit.dart';
import 'local_storage_service.dart';

class NotificationService {
  NotificationService._();
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // tz.local remains the fallback if the platform timezone cannot be read.
    }
    const android = AndroidInitializationSettings('ic_habit_notification');
    const settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      macOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> requestPermissions() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? true;
  }

  static Future<void> scheduleHabitReminders(List<Habit> habits) async {
    await initialize();
    await requestPermissions();
    await _plugin.cancelAll();
    var id = 1000;
    final now = tz.TZDateTime.now(tz.local);
    for (final habit in habits.where((h) => !h.isArchived)) {
      final details = const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit reminders',
          channelDescription: 'Daily reminders for scheduled habits',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      if (habit.scheduleType == HabitScheduleType.daily) {
        await _schedule(id++, habit, now, details, DateTimeComponents.time);
      } else {
        for (final weekday in habit.scheduledWeekdays) {
          final next = _nextWeekday(now, weekday);
          await _schedule(id++, habit, next, details, DateTimeComponents.dayOfWeekAndTime);
        }
      }
    }
  }

  static Future<void> _schedule(int id, Habit habit, tz.TZDateTime date, NotificationDetails details, DateTimeComponents components) async {
    await _plugin.zonedSchedule(
      id: id,
      title: 'Habit reminder',
      body: 'Time for “${habit.name}”. Keep your streak alive! 🔥',
      scheduledDate: date,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
    );
  }

  static tz.TZDateTime _nextWeekday(tz.TZDateTime now, int weekday) {
    var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    var delta = (weekday - date.weekday + 7) % 7;
    if (delta == 0 && !date.isAfter(now)) delta = 7;
    return date.add(Duration(days: delta));
  }


  static Future<void> showActivityNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!await _notificationsEnabled()) return;
    await initialize();
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_updates',
          'Habit updates',
          channelDescription: 'Helpful updates about your habit activity',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<bool> _notificationsEnabled() async {
    // The app preference is authoritative; Android permission is requested by
    // the settings screen and the reminder scheduler.
    return LocalStorageService.loadNotificationsEnabled();
  }

  static Future<void> cancelAll() async { await initialize(); await _plugin.cancelAll(); }

  static Future<void> showTestNotification() async {
    await initialize();
    await requestPermissions();
    await _plugin.show(
      id: 99999,
      title: 'Habit Tracker notifications are on',
      body: 'Your habit reminders are ready.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('habit_reminders', 'Habit reminders', channelDescription: 'Daily reminders for scheduled habits', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
