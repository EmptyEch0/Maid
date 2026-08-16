import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isContinuousListening = false;
  Function(String text)? _wakeWordCallback;

  SpeechService._init();

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (err) {
          debugPrint('Speech error: $err');
          if (_isContinuousListening) {
            _restartContinuousListening();
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (_isContinuousListening) {
              _restartContinuousListening();
            }
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('Speech init exception: $e');
      return false;
    }
  }

  bool get isListening => _speech.isListening;
  bool get isContinuousListening => _isContinuousListening;

  Future<void> listen({required Function(String text) onResult}) async {
    if (!_isAvailable) {
      final ok = await init();
      if (!ok) return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      return;
    }

    await _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  /// Starts continuous wake-word listening ("Hey Maid" / "Maid ...")
  Future<void> startWakeWordMonitoring({required Function(String query) onQuery}) async {
    _isContinuousListening = true;
    _wakeWordCallback = onQuery;
    await _startWakeWordCycle();
  }

  Future<void> _startWakeWordCycle() async {
    if (!_isAvailable) {
      final ok = await init();
      if (!ok) return;
    }

    if (_speech.isListening) return;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;

          final lower = words.toLowerCase();
          // Check for wake words: "hey maid", "maid", "ok maid", "hi maid"
          if (lower.contains('maid') || lower.contains('made')) {
            String query = words;
            // Strip out the wake word prefix if desired
            final cleaned = words.replaceFirst(RegExp(r'^(hey|ok|hi|hello)?\s*(maid|made)\s*[:,]?', caseSensitive: false), '').trim();
            if (cleaned.isNotEmpty) {
              query = cleaned;
            }
            _wakeWordCallback?.call(query.isEmpty ? "what is today schedule" : query);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('Error starting wake word cycle: $e');
    }
  }

  void _restartContinuousListening() {
    if (!_isContinuousListening) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isContinuousListening && !_speech.isListening) {
        _startWakeWordCycle();
      }
    });
  }

  Future<void> stop() async {
    _isContinuousListening = false;
    _wakeWordCallback = null;
    await _speech.stop();
  }
}
