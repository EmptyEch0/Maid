import 'dart:async';
import '../models/app_models.dart';
import 'notification_service.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  AlarmService._init();

  Timer? _checkTimer;
  final _alarmTriggerController = StreamController<AlarmItem>.broadcast();
  Stream<AlarmItem> get onAlarmTriggered => _alarmTriggerController.stream;

  final Set<String> _triggeredInCurrentMinute = {};
  String _lastCheckedMinute = '';

  void startMonitoring(List<AlarmItem> Function() getActiveAlarms) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAlarms(getActiveAlarms());
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }

  void _checkAlarms(List<AlarmItem> alarms) {
    final now = DateTime.now();
    final currentMinuteStr = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    final currentDayAbbr = _getDayAbbr(now.weekday);

    if (_lastCheckedMinute != currentMinuteStr) {
      _lastCheckedMinute = currentMinuteStr;
      _triggeredInCurrentMinute.clear();
    }

    final formattedHour = now.hour.toString().padLeft(2, '0');
    final formattedMinute = now.minute.toString().padLeft(2, '0');
    final timeNowStr = '$formattedHour:$formattedMinute';

    for (final alarm in alarms) {
      if (!alarm.isEnabled) continue;

      // Check repeat days if specified
      if (alarm.repeatDays.isNotEmpty && !alarm.repeatDays.contains(currentDayAbbr)) {
        continue;
      }

      if (alarm.time == timeNowStr && !_triggeredInCurrentMinute.contains(alarm.id)) {
        _triggeredInCurrentMinute.add(alarm.id);
        triggerAlarm(alarm);
      }
    }
  }

  void triggerAlarm(AlarmItem alarm) {
    // Schedule notification
    final notificationId = alarm.id.hashCode & 0x7FFFFFFF;
    NotificationService.instance.scheduleNotification(
      id: notificationId,
      title: '⏰ WAKE UP: ${alarm.title}',
      body: alarm.description.isNotEmpty ? alarm.description : 'Your alarm is ringing!',
      scheduledDate: DateTime.now().add(const Duration(seconds: 1)),
    );

    // Emit live stream for UI ringing overlay
    _alarmTriggerController.add(alarm);
  }

  String _getDayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _alarmTriggerController.close();
  }
}
