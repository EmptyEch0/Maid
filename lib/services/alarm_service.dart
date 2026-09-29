import 'dart:async';
import '../models/app_models.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  AlarmService._init();

  Timer? _checkTimer;
  final _alarmTriggerController = StreamController<AlarmItem>.broadcast();
  Stream<AlarmItem> get onAlarmTriggered => _alarmTriggerController.stream;

  final Set<String> _triggeredInCurrentMinute = {};
  String _lastCheckedMinute = '';
  final Map<String, DateTime> _snoozedUntil = {};

  void startMonitoring(List<AlarmItem> Function() getActiveAlarms) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAlarms(getActiveAlarms());
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }

  void snooze(String alarmId, DateTime until) {
    _snoozedUntil[alarmId] = until;
  }

  void clearSnooze(String alarmId) {
    _snoozedUntil.remove(alarmId);
  }

  void _checkAlarms(List<AlarmItem> alarms) {
    final now = DateTime.now();
    final currentMinuteStr = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    final currentDayAbbr = _getDayAbbr(now.weekday);

    if (_lastCheckedMinute != currentMinuteStr) {
      _lastCheckedMinute = currentMinuteStr;
      _triggeredInCurrentMinute.clear();
    }

    for (final alarm in alarms) {
      final snoozeUntil = _snoozedUntil[alarm.id];
      if (snoozeUntil != null && !now.isBefore(snoozeUntil)) {
        _snoozedUntil.remove(alarm.id);
        _triggeredInCurrentMinute.add(alarm.id);
        triggerAlarm(alarm);
        continue;
      }

      if (!alarm.isEnabled) continue;

      // Check repeat days if specified
      if (alarm.repeatDays.isNotEmpty && !alarm.repeatDays.contains(currentDayAbbr)) {
        continue;
      }

      final parsed = TimeHelper.parseTime(alarm.time);
      if (now.hour == parsed.hour && now.minute == parsed.minute && !_triggeredInCurrentMinute.contains(alarm.id)) {
        _triggeredInCurrentMinute.add(alarm.id);
        triggerAlarm(alarm);
      }
    }
  }

  /// Foreground-only: shows the in-app ringing overlay. The OS-level notification scheduled by
  /// NotificationService rings independently, including when the app is closed.
  void triggerAlarm(AlarmItem alarm) {
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
