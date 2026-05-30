import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Initialize once at app startup
  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Request exact alarm permission (Android 12+)
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  // Notification channel details
  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'taskflow_reminders',
      'Task Reminders',
      channelDescription: 'Reminders for upcoming task deadlines',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  // Schedule a notification for a task deadline
  // notificationId: use task hashcode so each task has a unique id
  // reminderType: 'hours_before' or 'morning_of'
  // hoursBeforeDeadline: used only when reminderType == 'hours_before'
  Future<void> scheduleTaskReminder({
    required int notificationId,
    required String taskTitle,
    required DateTime deadline,
    required String reminderType,
    int hoursBeforeDeadline = 1,
  }) async {
    DateTime scheduledTime;

    if (reminderType == 'morning_of') {
      // 8:00 AM on the day of the deadline
      scheduledTime = DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        8,
        0,
      );
    } else {
      // X hours before deadline
      scheduledTime = deadline.subtract(Duration(hours: hoursBeforeDeadline));
    }

    // Don't schedule if the time is already in the past
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      notificationId,
      '⏰ Task Reminder',
      reminderType == 'morning_of'
          ? '"$taskTitle" is due today!'
          : '"$taskTitle" is due in $hoursBeforeDeadline hour${hoursBeforeDeadline > 1 ? 's' : ''}!',
      tzScheduledTime,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancel a specific task's notification
  Future<void> cancelTaskReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  // Cancel all notifications (e.g. on logout)
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // Generate a consistent int ID from a Firestore task ID string
  static int idFromTaskId(String taskId) {
    return taskId.hashCode.abs();
  }
}
