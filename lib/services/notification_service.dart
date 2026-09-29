import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/app_models.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Function(String? payload)? onNotificationClick;

  NotificationService._init();

  // Android notification channels are immutable once created on a device, so any change to
  // sound/vibration/importance requires a NEW channel id. The old ids are deleted in init().
  static const String _alarmChannelId = 'maid_alarms_v2';
  static const String _alarmNoVibChannelId = 'maid_alarms_novib_v2';
  static const String _reminderChannelId = 'maid_reminders_v2';
  static const String _reminderNoVibChannelId = 'maid_reminders_novib_v2';
  static const List<String> _legacyChannelIds = ['maid_alarm_channel', 'maid_channel_id'];

  // System default alarm ringtone (same one the stock Clock app uses)
  static const _alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');
  static final Int64List _alarmVibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

  // FLAG_INSISTENT: keeps the sound/vibration looping until the notification is tapped or swiped away
  static final Int32List _insistentFlag = Int32List.fromList([4]);

  static const _dayMap = {
    'Mon': DateTime.monday,
    'Tue': DateTime.tuesday,
    'Wed': DateTime.wednesday,
    'Thu': DateTime.thursday,
    'Fri': DateTime.friday,
    'Sat': DateTime.saturday,
    'Sun': DateTime.sunday,
  };

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    _configureLocalTimeZone();

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

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      for (final legacyId in _legacyChannelIds) {
        await androidPlugin.deleteNotificationChannel(legacyId);
      }

      await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
        _alarmChannelId,
        'Maid Alarms',
        description: 'Wake-up alarms and daily briefings that ring like a real alarm clock',
        importance: Importance.max,
        playSound: true,
        sound: _alarmSound,
        enableVibration: true,
        vibrationPattern: _alarmVibrationPattern,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        _alarmNoVibChannelId,
        'Maid Alarms (no vibration)',
        description: 'Wake-up alarms with vibration turned off',
        importance: Importance.max,
        playSound: true,
        sound: _alarmSound,
        enableVibration: false,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        _reminderChannelId,
        'Maid Reminders & Events',
        description: 'Calendar event reminders and task alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        _reminderNoVibChannelId,
        'Maid Reminders & Events (no vibration)',
        description: 'Calendar event reminders and task alerts with vibration turned off',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
      ));
    }

    _isInitialized = true;
  }

  /// tz.local defaults to UTC unless set. Pick the IANA zone matching the device's current
  /// offset (preferring a matching abbreviation) so daily/weekly repeats land on local time.
  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;
      final abbreviation = now.timeZoneName;
      tz.Location? match;
      for (final location in tz.timeZoneDatabase.locations.values) {
        final zone = location.timeZone(now.millisecondsSinceEpoch);
        if (zone.offset != offsetMs) continue;
        if (zone.abbreviation == abbreviation) {
          match = location;
          break;
        }
        match ??= location;
      }
      if (match != null) tz.setLocalLocation(match);
    } catch (e) {
      debugPrint('Timezone setup failed, using UTC: $e');
    }
  }

  Future<void> requestPermissions() async {
    _exactAllowedCache = null;
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

  /// Payload of the notification that cold-started the app (tapped while the app was killed)
  Future<String?> getLaunchPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  bool? _exactAllowedCache;
  DateTime _exactCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Cached briefly: syncing many alarms/events would otherwise make one platform call each
  Future<bool> _canScheduleExact() async {
    final cached = _exactAllowedCache;
    if (cached != null && DateTime.now().difference(_exactCheckedAt) < const Duration(minutes: 1)) {
      return cached;
    }
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final allowed = androidPlugin == null ? true : (await androidPlugin.canScheduleExactNotifications() ?? true);
    _exactAllowedCache = allowed;
    _exactCheckedAt = DateTime.now();
    return allowed;
  }

  /// Central scheduling helper. Uses setAlarmClock for alarms (the most reliable mode — survives
  /// Doze and OEM battery savers) and falls back to inexact scheduling if exact alarms are denied,
  /// so a missing permission degrades to "a bit late" instead of "never".
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? repeat,
    bool alarmClock = false,
  }) async {
    final exact = await _canScheduleExact();
    final mode = !exact
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : (alarmClock ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle);
    if (!exact) {
      debugPrint('Exact alarms not permitted — notification $id scheduled inexactly');
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      payload: payload,
      androidScheduleMode: mode,
      matchDateTimeComponents: repeat,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  NotificationDetails _alarmDetails({required bool vibrate, bool insistent = true, String? channelDescription}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        vibrate ? _alarmChannelId : _alarmNoVibChannelId,
        vibrate ? 'Maid Alarms' : 'Maid Alarms (no vibration)',
        channelDescription: channelDescription ?? 'Wake-up alarms that ring like a real alarm clock',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: _alarmSound,
        enableVibration: vibrate,
        vibrationPattern: vibrate ? _alarmVibrationPattern : null,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        additionalFlags: insistent ? _insistentFlag : null,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  NotificationDetails _reminderDetails({required bool vibrate}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        vibrate ? _reminderChannelId : _reminderNoVibChannelId,
        vibrate ? 'Maid Reminders & Events' : 'Maid Reminders & Events (no vibration)',
        channelDescription: 'Calendar event reminders and task alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrate,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Calculates the next upcoming trigger time for an alarm
  DateTime calculateNextTriggerTime(String timeStr, List<String> repeatDays) {
    final parsed = TimeHelper.parseTime(timeStr);
    final now = DateTime.now();

    for (int i = 0; i < 8; i++) {
      final checkDate = now.add(Duration(days: i));
      final checkTarget = DateTime(checkDate.year, checkDate.month, checkDate.day, parsed.hour, parsed.minute);
      if (checkTarget.isBefore(now.add(const Duration(seconds: 5)))) continue;
      if (repeatDays.isEmpty) return checkTarget;

      final weekdayName = _dayMap.entries
          .firstWhere((e) => e.value == checkDate.weekday, orElse: () => const MapEntry('', 0))
          .key;
      if (repeatDays.contains(weekdayName)) return checkTarget;
    }

    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute).add(const Duration(days: 1));
  }

  /// Next local occurrence of [hour]:[minute], optionally on a given [weekday], strictly in the future
  tz.TZDateTime _nextInstanceOf(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (!target.isAfter(now.add(const Duration(seconds: 5))) ||
        (weekday != null && target.weekday != weekday)) {
      target = tz.TZDateTime(tz.local, target.year, target.month, target.day + 1, hour, minute);
    }
    return target;
  }

  // Each alarm owns 16 notification ids: slot 0 = one-time, 1..7 = weekday repeats (Mon..Sun), 8 = snooze
  int _alarmSlotId(String alarmId, int slot) => (alarmId.hashCode & 0x07FFFFFF) * 16 + slot;
  static const int _oneTimeSlot = 0;
  static const int _snoozeSlot = 8;

  String _oneTimeFireKey(String alarmId) => 'alarm_fire_at_$alarmId';

  /// When a one-time alarm was last scheduled to ring. Used on launch to switch off one-time
  /// alarms that already rang while the app was closed, instead of re-arming them for tomorrow.
  Future<DateTime?> oneTimeAlarmFireTime(String alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_oneTimeFireKey(alarmId));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _rememberOneTimeFire(String alarmId, DateTime? when) async {
    final prefs = await SharedPreferences.getInstance();
    if (when == null) {
      await prefs.remove(_oneTimeFireKey(alarmId));
    } else {
      await prefs.setInt(_oneTimeFireKey(alarmId), when.millisecondsSinceEpoch);
    }
  }

  String _alarmTitle(AlarmItem alarm) => '⏰ ALARM: ${alarm.title}';
  String _alarmBody(AlarmItem alarm) =>
      alarm.description.isNotEmpty ? alarm.description : 'Time to wake up for: ${alarm.title}';

  /// Schedules an alarm at the OS level. Repeating alarms are registered once per weekday with
  /// weekly repetition, so they keep ringing even if the app is never reopened.
  Future<void> scheduleAlarmNotification(AlarmItem alarm, {bool enableVibration = true}) async {
    await cancelAlarmNotification(alarm.id);
    if (!alarm.isEnabled) return;

    try {
      final parsed = TimeHelper.parseTime(alarm.time);
      final details = _alarmDetails(vibrate: alarm.vibrate && enableVibration);

      if (alarm.repeatDays.isEmpty) {
        final when = _nextInstanceOf(parsed.hour, parsed.minute);
        await _schedule(
          id: _alarmSlotId(alarm.id, _oneTimeSlot),
          title: _alarmTitle(alarm),
          body: _alarmBody(alarm),
          when: when,
          details: details,
          payload: alarm.id,
          alarmClock: true,
        );
        await _rememberOneTimeFire(alarm.id, when);
        return;
      }

      await _scheduleWeeklyRepeats(alarm, parsed.hour, parsed.minute, details);
    } catch (e) {
      debugPrint('Failed to schedule alarm ${alarm.id}: $e');
    }
  }

  Future<void> _scheduleWeeklyRepeats(AlarmItem alarm, int hour, int minute, NotificationDetails details) async {
    for (final day in alarm.repeatDays) {
      final weekday = _dayMap[day];
      if (weekday == null) continue;
      await _schedule(
        id: _alarmSlotId(alarm.id, weekday),
        title: _alarmTitle(alarm),
        body: _alarmBody(alarm),
        when: _nextInstanceOf(hour, minute, weekday: weekday),
        details: details,
        payload: alarm.id,
        repeat: DateTimeComponents.dayOfWeekAndTime,
        alarmClock: true,
      );
    }
  }

  /// Snoozes without touching the alarm's configured time: repeats stay armed, and a separate
  /// one-shot notification rings at [until].
  Future<void> snoozeAlarmNotification(AlarmItem alarm, DateTime until, {bool enableVibration = true}) async {
    await cancelAlarmNotification(alarm.id);

    try {
      final details = _alarmDetails(vibrate: alarm.vibrate && enableVibration);
      if (alarm.repeatDays.isNotEmpty) {
        final parsed = TimeHelper.parseTime(alarm.time);
        await _scheduleWeeklyRepeats(alarm, parsed.hour, parsed.minute, details);
      } else {
        await _rememberOneTimeFire(alarm.id, until);
      }

      await _schedule(
        id: _alarmSlotId(alarm.id, _snoozeSlot),
        title: '😴 SNOOZED: ${alarm.title}',
        body: _alarmBody(alarm),
        when: tz.TZDateTime.from(until, tz.local),
        details: details,
        payload: alarm.id,
        alarmClock: true,
      );
    } catch (e) {
      debugPrint('Failed to snooze alarm ${alarm.id}: $e');
    }
  }

  Future<void> cancelAlarmNotification(String alarmId) async {
    await Future.wait([
      // Legacy single id used by older builds
      _notifications.cancel(alarmId.hashCode & 0x7FFFFFFF),
      for (int slot = 0; slot <= _snoozeSlot; slot++) _notifications.cancel(_alarmSlotId(alarmId, slot)),
      _rememberOneTimeFire(alarmId, null),
    ]);
  }

  /// Syncs and schedules all active alarms
  Future<void> syncAllAlarms(List<AlarmItem> alarms, {bool enableVibration = true}) async {
    for (final alarm in alarms) {
      await scheduleAlarmNotification(alarm, enableVibration: enableVibration);
    }
  }

  /// Syncs and schedules all upcoming calendar events
  Future<void> syncAllEvents(List<CalendarEvent> events, {bool enableVibration = true}) async {
    for (final event in events) {
      await scheduleEventReminder(event, enableVibration: enableVibration);
    }
  }

  /// Schedules an event reminder (supports pre-date like 1-day before, 1-hour before, etc.)
  Future<void> scheduleEventReminder(CalendarEvent event, {bool enableVibration = true}) async {
    if (event.reminderMinutesBefore < 0) {
      await cancelEventReminder(event.id);
      return;
    }

    try {
      final dateParts = event.date.split('-');
      final parsedTime = TimeHelper.parseTime(event.startTime);
      if (dateParts.length != 3) return;

      final eventStartTime = tz.TZDateTime(
        tz.local,
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        parsedTime.hour,
        parsedTime.minute,
      );
      final reminderTime = eventStartTime.subtract(Duration(minutes: event.reminderMinutesBefore));

      if (reminderTime.isBefore(DateTime.now())) {
        await cancelEventReminder(event.id);
        return;
      }

      String bodyText;
      if (event.reminderMinutesBefore == 1440) {
        bodyText = '📅 Upcoming tomorrow at ${event.startTime}: ${event.title} (${event.category})';
      } else if (event.reminderMinutesBefore >= 60) {
        final hours = event.reminderMinutesBefore ~/ 60;
        bodyText = '⏰ Starts in $hours hour(s) at ${event.startTime}: ${event.title}';
      } else if (event.reminderMinutesBefore > 0) {
        bodyText = '⏰ Starts in ${event.reminderMinutesBefore} minutes at ${event.startTime}: ${event.title}';
      } else {
        bodyText = '🎯 Event starting now: ${event.title} (${event.startTime} - ${event.endTime})';
      }

      await _schedule(
        id: event.id.hashCode & 0x7FFFFFFF,
        title: '📅 Event Reminder: ${event.title}',
        body: bodyText,
        when: reminderTime,
        details: _reminderDetails(vibrate: enableVibration),
        payload: 'event_${event.id}',
      );
    } catch (e) {
      debugPrint('Failed to schedule reminder for event ${event.id}: $e');
    }
  }

  Future<void> cancelEventReminder(String eventId) async {
    final int notifId = eventId.hashCode & 0x7FFFFFFF;
    await _notifications.cancel(notifId);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool enableVibration = true,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;
    try {
      await _schedule(
        id: id,
        title: title,
        body: body,
        when: tz.TZDateTime.from(scheduledDate, tz.local),
        details: _reminderDetails(vibrate: enableVibration),
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
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
      final mParsed = TimeHelper.parseTime(morningTime);
      final eParsed = TimeHelper.parseTime(eveningTime);

      // Rings with the alarm tone (plays through once, not looping)
      final briefingDetails = _alarmDetails(
        vibrate: enableVibration,
        insistent: false,
        channelDescription: 'Daily morning and evening briefings',
      );

      await _schedule(
        id: morningBriefingNotifId,
        title: '☀️ Good Morning $userName! — Maid Briefing',
        body: 'Hey $userName, your daily plan is ready with tasks and schedule. Tap to hear your voice briefing!',
        when: _nextInstanceOf(mParsed.hour, mParsed.minute),
        details: briefingDetails,
        payload: 'daily_briefing_morning',
        repeat: DateTimeComponents.time,
        alarmClock: true,
      );

      await _schedule(
        id: eveningBriefingNotifId,
        title: '🌙 Evening Wrap-Up — Maid Briefing',
        body: 'Hey $userName, Maid here with your nightly task review. Tap to check your remaining pending work!',
        when: _nextInstanceOf(eParsed.hour, eParsed.minute),
        details: briefingDetails,
        payload: 'daily_briefing_evening',
        repeat: DateTimeComponents.time,
        alarmClock: true,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily briefings: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
