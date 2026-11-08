import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';

/// Android only: the daily morning/evening briefings are scheduled and spoken natively
/// (BriefingScheduler.kt / BriefingSpeechService.kt), so the voice plays at the set time even when
/// the app is closed. Flutter just keeps the settings and pre-written briefing texts in sync.
class BriefingVoiceService {
  static final BriefingVoiceService instance = BriefingVoiceService._init();
  BriefingVoiceService._init();

  static const MethodChannel _channel = MethodChannel('com.maid.app/briefing');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// [texts] maps "morning_YYYY-MM-DD" / "evening_YYYY-MM-DD" to the sentence to speak that day.
  Future<void> configure({
    required bool enabled,
    required bool speak,
    required String morningTime,
    required String eveningTime,
    required String userName,
    required Map<String, String> texts,
  }) async {
    if (!isSupported) return;
    final morning = TimeHelper.parseTime(morningTime);
    final evening = TimeHelper.parseTime(eveningTime);
    try {
      await _channel.invokeMethod('configure', {
        'enabled': enabled,
        'speak': speak,
        'morningMinutes': morning.hour * 60 + morning.minute,
        'eveningMinutes': evening.hour * 60 + evening.minute,
        'userName': userName,
        'texts': texts,
      });
    } catch (e) {
      debugPrint('Failed to sync voice briefings: $e');
    }
  }

  /// Plays the real scheduled briefing after [delaySeconds], so it can be tested with the app closed
  Future<void> test({required bool isEvening, int delaySeconds = 60}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('test', {
        'kind': isEvening ? 'evening' : 'morning',
        'delaySeconds': delaySeconds,
      });
    } catch (e) {
      debugPrint('Failed to schedule test briefing: $e');
    }
  }
}
