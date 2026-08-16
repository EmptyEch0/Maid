import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';
import '../services/audio_haptics_service.dart';

enum TimerMode { stopwatch, pomodoro }
enum PomodoroPhase { work, shortBreak, longBreak }

class StudyTimerEngine extends ChangeNotifier {
  TimerMode _mode = TimerMode.stopwatch;
  PomodoroPhase _phase = PomodoroPhase.work;
  
  bool _isRunning = false;
  bool _isPaused = false;

  int _elapsedSeconds = 0;
  int _targetMinutes = 25; // Planned study duration
  int _currentCycle = 1;
  int _pausedMsTotal = 0;

  DateTime? _startTime;
  DateTime? _pauseStartTime;
  Timer? _timer;

  String _currentSubject = 'General';
  PomodoroSettings _pomodoroSettings = PomodoroSettings(id: 'default');

  // Getters
  TimerMode get mode => _mode;
  PomodoroPhase get phase => _phase;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get elapsedSeconds => _elapsedSeconds;
  int get targetMinutes => _targetMinutes;
  int get currentCycle => _currentCycle;
  String get currentSubject => _currentSubject;
  PomodoroSettings get pomodoroSettings => _pomodoroSettings;

  int get remainingSeconds {
    if (_mode == TimerMode.stopwatch) {
      return (_targetMinutes * 60) - _elapsedSeconds;
    } else {
      int phaseTargetSec = _getPhaseTargetMinutes() * 60;
      return phaseTargetSec - _elapsedSeconds;
    }
  }

  int _getPhaseTargetMinutes() {
    switch (_phase) {
      case PomodoroPhase.work:
        return _pomodoroSettings.workMinutes;
      case PomodoroPhase.shortBreak:
        return _pomodoroSettings.breakMinutes;
      case PomodoroPhase.longBreak:
        return _pomodoroSettings.longBreakMinutes;
    }
  }

  void setSubject(String subject) {
    _currentSubject = subject;
    notifyListeners();
  }

  void setTargetMinutes(int minutes) {
    _targetMinutes = minutes;
    notifyListeners();
  }

  void setMode(TimerMode newMode) {
    if (_isRunning) reset();
    _mode = newMode;
    _phase = PomodoroPhase.work;
    notifyListeners();
  }

  void updatePomodoroSettings(PomodoroSettings settings) {
    _pomodoroSettings = settings;
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _startTime ??= DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      if (_mode == TimerMode.pomodoro && remainingSeconds <= 0) {
        _handlePomodoroPhaseCompletion();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    if (!_isRunning || _isPaused) return;
    _timer?.cancel();
    _isPaused = true;
    _isRunning = false;
    _pauseStartTime = DateTime.now();
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    if (_pauseStartTime != null) {
      _pausedMsTotal += DateTime.now().difference(_pauseStartTime!).inMilliseconds;
    }
    _isPaused = false;
    start();
  }

  void reset() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _elapsedSeconds = 0;
    _pausedMsTotal = 0;
    _startTime = null;
    _pauseStartTime = null;
    _phase = PomodoroPhase.work;
    _currentCycle = 1;
    notifyListeners();
  }

  void _handlePomodoroPhaseCompletion() {
    _timer?.cancel();
    _isRunning = false;
    _elapsedSeconds = 0;

    if (_phase == PomodoroPhase.work) {
      AudioHapticsService.playPhaseTransitionAlert(isBreakStarting: true);
      if (_currentCycle >= _pomodoroSettings.cyclesBeforeLongBreak) {
        _phase = PomodoroPhase.longBreak;
        _currentCycle = 1;
      } else {
        _phase = PomodoroPhase.shortBreak;
        _currentCycle++;
      }
    } else {
      AudioHapticsService.playPhaseTransitionAlert(isBreakStarting: false);
      _phase = PomodoroPhase.work;
    }
    notifyListeners();
  }

  StudySession completeSession({String? notes}) {
    final now = DateTime.now();
    final startTsStr = (_startTime ?? now).toIso8601String();
    final endTsStr = now.toIso8601String();
    final actualMins = (_elapsedSeconds / 60).round();

    final session = StudySession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: _currentSubject,
      plannedMinutes: _targetMinutes,
      actualMinutes: actualMins,
      startTs: startTsStr,
      endTs: endTsStr,
      pausedMs: _pausedMsTotal,
      notes: notes,
    );

    reset();
    return session;
  }
}
