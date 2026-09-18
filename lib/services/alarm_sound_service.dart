import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

/// Service that handles alarm sound playback using just_audio and system sounds.
/// Supports playing custom audio files from device storage and varied tone rhythm patterns.
class AlarmSoundService {
  static final AlarmSoundService instance = AlarmSoundService._init();
  AlarmSoundService._init();

  AudioPlayer? _alarmPlayer;
  Timer? _fallbackTimer;
  String? _currentPlayingTone;

  String? get currentPlayingTone => _currentPlayingTone;

  /// Play an alarm sound. If [filePath] is provided, plays that local file.
  /// Otherwise plays a distinct rhythm/tone alert pattern.
  Future<void> playAlarmSound({String? filePath, String toneName = 'Gentle Chime', bool loop = true}) async {
    await stopAlarmSound(); // Stop any existing playback
    _currentPlayingTone = toneName;

    try {
      if (filePath != null && filePath.isNotEmpty) {
        _alarmPlayer = AudioPlayer();
        await _alarmPlayer!.setFilePath(filePath);
        if (loop) {
          await _alarmPlayer!.setLoopMode(LoopMode.one);
        }
        await _alarmPlayer!.setVolume(1.0);
        await _alarmPlayer!.play();
        return;
      }

      // If preset tone without custom file path:
      _playPresetTonePattern(toneName: toneName, loop: loop, durationSeconds: 60);
    } catch (e) {
      _playPresetTonePattern(toneName: toneName, loop: loop, durationSeconds: 60);
    }
  }

  /// Play a preview of a tone (non-looping, short duration ~4 seconds)
  Future<void> playPreview({String? filePath, String toneName = 'Gentle Chime'}) async {
    await stopAlarmSound();
    _currentPlayingTone = toneName;

    try {
      if (filePath != null && filePath.isNotEmpty) {
        _alarmPlayer = AudioPlayer();
        await _alarmPlayer!.setFilePath(filePath);
        await _alarmPlayer!.setLoopMode(LoopMode.off);
        await _alarmPlayer!.setVolume(1.0);
        await _alarmPlayer!.play();

        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(seconds: 4), () {
          stopAlarmSound();
        });
        return;
      }

      _playPresetTonePattern(toneName: toneName, loop: false, durationSeconds: 4);
    } catch (_) {
      _playPresetTonePattern(toneName: toneName, loop: false, durationSeconds: 4);
    }
  }

  /// Plays distinctive rhythmic sound and vibration patterns based on tone name
  void _playPresetTonePattern({required String toneName, bool loop = true, int durationSeconds = 60}) {
    _fallbackTimer?.cancel();

    int intervalMs = 600;
    if (toneName.contains('Energetic') || toneName.contains('Radar') || toneName.contains('Siren')) {
      intervalMs = 350;
    } else if (toneName.contains('Zen') || toneName.contains('Morning')) {
      intervalMs = 900;
    } else if (toneName.contains('Digital') || toneName.contains('Beep')) {
      intervalMs = 450;
    }

    int elapsed = 0;
    _fallbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      elapsed++;
      try {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();

        if (intervalMs < 500) {
          Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.vibrate();
          });
        }
      } catch (_) {}

      if (!loop || elapsed > (durationSeconds * 1000 ~/ intervalMs)) {
        timer.cancel();
        _currentPlayingTone = null;
      }
    });
  }

  /// Stop any currently playing alarm sound
  Future<void> stopAlarmSound() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _currentPlayingTone = null;

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
