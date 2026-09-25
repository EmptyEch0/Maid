import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'tts_service.dart';

class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isContinuousListening = false;
  Function(String text)? _wakeWordCallback;
  Function()? _stopCommandCallback;

  SpeechService._init();

  /// Checks if spoken words represent a stop/silence/cancel command
  static bool isStopCommand(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // Explicit non-stop commands (creating tasks with the word "stop by", etc.)
    if (lower.startsWith('add task') ||
        lower.startsWith('create task') ||
        lower.startsWith('new task') ||
        lower.startsWith('task:') ||
        lower.startsWith('set alarm') ||
        lower.startsWith('tell my') ||
        lower.startsWith('what is') ||
        lower.startsWith('what\'s') ||
        lower.startsWith('show') ||
        lower.startsWith('search') ||
        lower.startsWith('find')) {
      return false;
    }

    // Direct single words / exact phrases
    const stopExact = {
      'stop',
      'shut up',
      'be quiet',
      'quiet',
      'silence',
      'mute',
      'halt',
      'cancel',
      'abort',
      'nevermind',
      'never mind',
      'pause',
      'enough',
      'hush',
      'shh',
      'stop talking',
      'stop speaking',
      'stop reading',
      'stop telling',
      'stop it',
      'stop now',
      'stop please',
      'please stop',
      'stop plan',
      'stop plans',
      'stop tasks',
      'stop work',
      'stop maid',
      'maid stop',
      'hey maid stop',
      'ok maid stop',
      'hi maid stop',
      'hello maid stop',
      'maid shut up',
      'hey maid shut up',
      'maid be quiet',
      'maid quiet',
      'maid silence',
      'maid mute',
      'maid pause',
      'maid cancel',
      'maid halt',
      'maid enough',
      'stop audio',
      'cut off',
      'don\'t speak',
      'dont speak',
      'stop listening',
    };

    if (stopExact.contains(lower)) {
      return true;
    }

    // Check regex pattern for any wake-word + stop word combination
    final RegExp stopPattern = RegExp(
      r'^(hey|ok|hi|hello)?\s*(maid|made)?\s*[:,]?\s*(please\s+)?(stop|shut\s*up|be\s*quiet|quiet|silence|mute|halt|cancel|abort|nevermind|never\s+mind|pause|enough|hush|stop\s+talking|stop\s+speaking|stop\s+reading|stop\s+telling|stop\s+tasks|stop\s+plans|stop\s+it|stop\s+now|stop\s+audio)(\s+please)?$',
      caseSensitive: false,
    );
    if (stopPattern.hasMatch(lower)) {
      return true;
    }

    return false;
  }

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

  Future<void> listen({
    required Function(String text) onResult,
    Function()? onStop,
  }) async {
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
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          if (isStopCommand(words)) {
            TtsService.instance.stop();
            onStop?.call();
            _speech.stop();
            return;
          }
          onResult(words);
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
  /// and voice stop listening ("Stop" / "Hey Maid Stop" / "Shut up" / "Be quiet")
  Future<void> startWakeWordMonitoring({
    required Function(String query) onQuery,
    Function()? onStop,
  }) async {
    _isContinuousListening = true;
    _wakeWordCallback = onQuery;
    _stopCommandCallback = onStop;
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

          // 1. Instant check for STOP command (including on partial recognition to cut off TTS audio immediately)
          if (isStopCommand(lower)) {
            TtsService.instance.stop();
            _stopCommandCallback?.call();
            return;
          }

          // 2. Check for wake words: "hey maid", "maid", "ok maid", "hi maid"
          if (lower.contains('maid') || lower.contains('made')) {
            final cleaned = words.replaceFirst(
              RegExp(r'^(hey|ok|hi|hello)?\s*(maid|made)\s*[:,]?', caseSensitive: false),
              '',
            ).trim();

            if (isStopCommand(cleaned)) {
              TtsService.instance.stop();
              _stopCommandCallback?.call();
              return;
            }

            // Only trigger assistant query callback on final result or when meaningful command exists
            if (result.finalResult || cleaned.length > 3) {
              String query = cleaned.isNotEmpty ? cleaned : words;
              _wakeWordCallback?.call(query.isEmpty ? "what is today schedule" : query);
            }
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
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
    _stopCommandCallback = null;
    await _speech.stop();
  }
}
