import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

/// Service that handles alarm sound playback using just_audio.
/// Supports playing system-style alarm alerts and custom audio files from device storage.
class AlarmSoundService {
  static final AlarmSoundService instance = AlarmSoundService._init();
  AlarmSoundService._init();

  AudioPlayer? _alarmPlayer;
  Timer? _fallbackTimer;

  /// Play an alarm sound. If [filePath] is provided, plays that local file.
  /// Otherwise plays a system-style alert tone using platform defaults.
  Future<void> playAlarmSound({String? filePath, bool loop = true}) async {
    await stopAlarmSound(); // Stop any existing playback

    try {
      _alarmPlayer = AudioPlayer();

      if (filePath != null && filePath.isNotEmpty) {
        // Play custom audio file from device
        await _alarmPlayer!.setFilePath(filePath);
      } else {
        // Play built-in asset tone or use system sound fallback
        // Use a looping system click + haptic as a fallback alarm
        _playSystemAlarmFallback(loop: loop);
        return;
      }

      if (loop) {
        await _alarmPlayer!.setLoopMode(LoopMode.one);
      }

      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.play();
    } catch (e) {
      // Fallback to system sound if audio playback fails
      _playSystemAlarmFallback(loop: loop);
    }
  }

  /// Play a preview of a tone (non-looping, short duration)
  Future<void> playPreview({String? filePath}) async {
    await stopAlarmSound();

    try {
      _alarmPlayer = AudioPlayer();

      if (filePath != null && filePath.isNotEmpty) {
        await _alarmPlayer!.setFilePath(filePath);
        await _alarmPlayer!.setLoopMode(LoopMode.off);
        await _alarmPlayer!.setVolume(1.0);
        await _alarmPlayer!.play();

        // Auto-stop preview after 5 seconds
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(seconds: 5), () {
          stopAlarmSound();
        });
      } else {
        // Preview system sound
        _playSystemAlarmFallback(loop: false, durationSeconds: 3);
      }
    } catch (_) {
      _playSystemAlarmFallback(loop: false, durationSeconds: 3);
    }
  }

  /// Fallback alarm using system sounds and haptics when no custom audio is available.
  /// Creates a repeating pattern of system clicks + vibrations to simulate an alarm.
  void _playSystemAlarmFallback({bool loop = true, int durationSeconds = 60}) {
    _fallbackTimer?.cancel();

    int elapsed = 0;
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      elapsed++;
      try {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();

        // Double vibration pattern for urgency
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.vibrate();
        });
      } catch (_) {}

      if (!loop || elapsed > (durationSeconds * 1000 ~/ 600)) {
        timer.cancel();
      }
    });
  }

  /// Stop any currently playing alarm sound
  Future<void> stopAlarmSound() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    try {
      if (_alarmPlayer != null) {
        await _alarmPlayer!.stop();
        await _alarmPlayer!.dispose();
        _alarmPlayer = null;
      }
    } catch (_) {
      _alarmPlayer = null;
    }
  }

  /// Check if alarm is currently playing
  bool get isPlaying => _alarmPlayer?.playing ?? (_fallbackTimer?.isActive ?? false);

  void dispose() {
    stopAlarmSound();
  }
}
