import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/app_models.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Function(String? payload)? onNotificationClick;

  NotificationService._init();

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationClick?.call(response.payload);
      },
    );

    // Create high priority Notification Channel for Alarms & Morning/Evening Briefings
    final AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'maid_alarm_channel',
      'Maid Alarms & Wake-Up Calls',
      description: 'Critical exact alarm notifications for waking up and scheduled tasks',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Calculates the next upcoming trigger time for an alarm
  DateTime calculateNextTriggerTime(String timeStr, List<String> repeatDays) {
    final parts = timeStr.split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

    final now = DateTime.now();

    if (repeatDays.isEmpty) {
      var target = DateTime(now.year, now.month, now.day, hour, minute);
      if (target.isBefore(now.add(const Duration(seconds: 5)))) {
        target = target.add(const Duration(days: 1));
      }
      return target;
    }

    const dayMap = {
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };

    DateTime? closest;
    for (int i = 0; i < 8; i++) {
      final checkDate = now.add(Duration(days: i));
      final checkTarget = DateTime(checkDate.year, checkDate.month, checkDate.day, hour, minute);
      if (checkTarget.isBefore(now.add(const Duration(seconds: 5)))) continue;

      final weekdayName = dayMap.entries
          .firstWhere((e) => e.value == checkDate.weekday, orElse: () => const MapEntry('', 0))
          .key;
      if (repeatDays.contains(weekdayName)) {
        closest = checkTarget;
        break;
      }
    }

    if (closest != null) return closest;

    var fallback = DateTime(now.year, now.month, now.day, hour, minute);
    if (fallback.isBefore(now)) fallback = fallback.add(const Duration(days: 1));
    return fallback;
  }

  /// Schedules an exact wake-up alarm notification
  Future<void> scheduleAlarmNotification(AlarmItem alarm, {bool enableVibration = true}) async {
    if (!alarm.isEnabled) {
      await cancelAlarmNotification(alarm.id);
      return;
    }

    try {
      final targetDate = calculateNextTriggerTime(alarm.time, alarm.repeatDays);
      final tz.TZDateTime tzDate = tz.TZDateTime.from(targetDate, tz.local);
      final int notifId = alarm.id.hashCode & 0x7FFFFFFF;

      final vibrationPattern = enableVibration
          ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000])
          : null;

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'maid_alarm_channel',
        'Maid Alarms & Wake-Up Calls',
        channelDescription: 'Critical exact alarm notifications for waking up and scheduled tasks',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: enableVibration,
        vibrationPattern: vibrationPattern,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: true,
        autoCancel: false,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      await _notifications.zonedSchedule(
        notifId,
        '⏰ ALARM: ${alarm.title}',
        alarm.description.isNotEmpty ? alarm.description : 'Time to wake up for: ${alarm.title}',
        tzDate,
        details,
        payload: alarm.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelAlarmNotification(String alarmId) async {
    final int notifId = alarmId.hashCode & 0x7FFFFFFF;
    await _notifications.cancel(notifId);
  }

  /// Syncs and schedules all active alarms
  Future<void> syncAllAlarms(List<AlarmItem> alarms, {bool enableVibration = true}) async {
    for (final alarm in alarms) {
      if (alarm.isEnabled) {
        await scheduleAlarmNotification(alarm, enableVibration: enableVibration);
      } else {
        await cancelAlarmNotification(alarm.id);
      }
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool enableVibration = true,
  }) async {
    try {
      final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'maid_channel_id',
        'Maid Reminders & Tasks',
        channelDescription: 'Local scheduled event & task notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: enableVibration,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static const int morningBriefingNotifId = 9001;
  static const int eveningBriefingNotifId = 9002;

  /// Schedules repeating daily morning & evening briefing reminders
  Future<void> scheduleDailyBriefings({
    required bool enabled,
    String morningTime = '09:00',
    String eveningTime = '20:00',
    String userName = 'Likhith',
    int pendingTasksCount = 0,
    int todayEventsCount = 0,
    bool enableVibration = true,
  }) async {
    // Cancel existing daily briefing notifications
    await cancelNotification(morningBriefingNotifId);
    await cancelNotification(eveningBriefingNotifId);

    if (!enabled) return;

    try {
      final now = DateTime.now();

      // 1. Morning Briefing (e.g. 09:00 AM)
      final mParts = morningTime.split(':');
      final mHour = int.tryParse(mParts[0]) ?? 9;
      final mMin = mParts.length > 1 ? int.tryParse(mParts[1]) ?? 0 : 0;

      var morningTarget = DateTime(now.year, now.month, now.day, mHour, mMin);
      if (morningTarget.isBefore(now)) {
        morningTarget = morningTarget.add(const Duration(days: 1));
      }
      final tz.TZDateTime tzMorning = tz.TZDateTime.from(morningTarget, tz.local);

      // 2. Evening Briefing (e.g. 08:00 PM / 20:00)
      final eParts = eveningTime.split(':');
      final eHour = int.tryParse(eParts[0]) ?? 20;
      final eMin = eParts.length > 1 ? int.tryParse(eParts[1]) ?? 0 : 0;

      var eveningTarget = DateTime(now.year, now.month, now.day, eHour, eMin);
      if (eveningTarget.isBefore(now)) {
        eveningTarget = eveningTarget.add(const Duration(days: 1));
      }
      final tz.TZDateTime tzEvening = tz.TZDateTime.from(eveningTarget, tz.local);

      final AndroidNotificationDetails briefingAndroidDetails = AndroidNotificationDetails(
        'maid_alarm_channel',
        'Maid Alarms & Wake-Up Calls',
        channelDescription: 'Daily morning and evening briefings with screen wake support',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: enableVibration,
        vibrationPattern: enableVibration
            ? Int64List.fromList([0, 800, 400, 800, 400, 800])
            : null,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      final NotificationDetails briefingDetails = NotificationDetails(
        android: briefingAndroidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      // Schedule Morning Briefing with Daily repeating components
      await _notifications.zonedSchedule(
        morningBriefingNotifId,
        '☀️ Good Morning $userName! — Maid Briefing',
        'Hey $userName, your daily plan is ready with tasks and schedule. Tap to hear your voice briefing!',
        tzMorning,
        briefingDetails,
        payload: 'daily_briefing_morning',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Schedule Evening Briefing with Daily repeating components
      await _notifications.zonedSchedule(
        eveningBriefingNotifId,
        '🌙 Evening Wrap-Up — Maid Briefing',
        'Hey $userName, Maid here with your nightly task review. Tap to check your remaining pending work!',
        tzEvening,
        briefingDetails,
        payload: 'daily_briefing_evening',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
