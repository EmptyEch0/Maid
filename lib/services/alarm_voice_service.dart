import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';

/// Android only: alarms ring natively as a "Maid is calling" voice alarm
/// (AlarmVoiceScheduler.kt / AlarmVoiceService.kt) — a female voice says
/// "Likhith, wake up! You have Meet with Satish..." until dismissed, even with the app closed.
class AlarmVoiceService {
  static final AlarmVoiceService instance = AlarmVoiceService._init();
  AlarmVoiceService._init();

  static const MethodChannel _channel = MethodChannel('com.maid.app/alarm');

  static const _isoWeekdays = {'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7};

  /// Name the voice calls out ("Likhith, wake up!"); kept in sync by AppProvider
  String userName = '';

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Map<String, dynamic> _alarmArgs(AlarmItem alarm, {required bool vibrate}) {
    final parsed = TimeHelper.parseTime(alarm.time);
    return {
      'id': alarm.id,
      'title': alarm.title,
      'description': alarm.description,
      'hour': parsed.hour,
      'minute': parsed.minute,
      'days': alarm.repeatDays.map((d) => _isoWeekdays[d]).whereType<int>().toList(),
      'vibrate': vibrate,
      'snoozeMinutes': alarm.snoozeDurationMinutes,
      'userName': userName,
    };
  }

  Future<void> schedule(AlarmItem alarm, {required bool vibrate}) async {
    if (!isSupported) return;
    await _invoke('schedule', _alarmArgs(alarm, vibrate: vibrate));
  }

  Future<void> cancel(String alarmId) async {
    if (!isSupported) return;
    await _invoke('cancel', {'id': alarmId});
  }

  Future<void> snooze(String alarmId, Duration delay) async {
    if (!isSupported) return;
    await _invoke('snooze', {'id': alarmId, 'delaySeconds': delay.inSeconds.clamp(5, 24 * 3600)});
  }

  /// Rings the voice alarm immediately (test button)
  Future<void> ringNow(AlarmItem alarm, {required bool vibrate}) async {
    if (!isSupported) return;
    await _invoke('ringTest', _alarmArgs(alarm, vibrate: vibrate));
  }

  /// Ids of one-time alarms that rang and were dismissed while the app was closed
  Future<List<String>> takeCompletedOneTime() async {
    if (!isSupported) return const [];
    try {
      final result = await _channel.invokeListMethod<String>('takeCompletedOneTime');
      return result ?? const [];
    } catch (e) {
      debugPrint('Voice alarm takeCompletedOneTime failed: $e');
      return const [];
    }
  }

  /// Android 14+: opens the "full-screen notifications" setting if it's off. Returns true if allowed.
  Future<bool> ensureFullScreenIntent() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('ensureFullScreenIntent') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } catch (e) {
      debugPrint('Voice alarm "$method" failed: $e');
    }
  }
}
