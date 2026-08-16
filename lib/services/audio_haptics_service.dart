import 'package:flutter/services.dart';

class AudioHapticsService {
  static void playPhaseTransitionAlert({required bool isBreakStarting}) {
    try {
      SystemSound.play(SystemSoundType.click);
      if (isBreakStarting) {
        // Double pulse for break time
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });
      } else {
        // Heavy vibration pulse for back to work
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticFeedback.vibrate();
        });
      }
    } catch (_) {
      // Haptics platform fallback
    }
  }

  static void playButtonFeedback() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
