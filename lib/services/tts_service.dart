import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  VoidCallback? onSpeechStarted;
  VoidCallback? onSpeechStopped;

  TtsService._init();

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeechStarted?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeechStopped?.call();
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeechStopped?.call();
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        onSpeechStopped?.call();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      await init();
      await _flutterTts.stop();
      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _flutterTts.stop();
      onSpeechStopped?.call();
    } catch (_) {}
  }
}
