import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/widget_update_service.dart';
import '../engine/scheduling_engine.dart';
import '../engine/weekly_review_engine.dart';
import '../engine/nlp_parser_engine.dart';

import '../services/alarm_service.dart';
import '../services/alarm_sound_service.dart';
import '../services/permission_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../engine/local_query_engine.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isUnlocked = true;
  String? _pinHash;
  bool _isPinSet = false;

  DateTime _selectedDate = DateTime.now();

  List<CalendarEvent> _events = [];
  List<RecurrenceRule> _recurrenceRules = [];
  List<ScheduleException> _exceptions = [];
  List<TaskItem> _tasks = [];
  List<NoteItem> _notes = [];
  List<StudySession> _studySessions = [];
  List<InboxItem> _inboxItems = [];
  List<AlarmItem> _alarms = [];
  List<HabitItem> _habits = [];

  List<String> _customAlarmTones = [
    'Gentle Chime',
    'Energetic Pulse',
    'Radar Alarm',
    'Classic Bell',
    'Morning Birds',
    'Digital Beep',
    'Zen Gong',
    'Vibrant Siren'
  ];
  List<String> _customReminderTones = [
    'Default Chime',
    'Soft Bell',
    'Double Click',
    'Ping Alert',
    'Zen Gong'
  ];
  String _defaultAlarmTone = 'Gentle Chime';
  String _defaultReminderTone = 'Default Chime';

  // Maps tone names to their file paths (null = system/preset tone)
  final Map<String, String?> _toneFilePaths = {};

  final Map<String, List<ChecklistItem>> _checklists = {};

  String _userName = 'Likhith';
  bool _dailyBriefingEnabled = true;
  String _morningBriefingTime = '08:00';
  String _eveningBriefingTime = '21:00';
  bool _wakeWordAutoTriggerEnabled = false;
  bool _autoSpeakBriefing = true;
  bool _vibrationEnabled = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isUnlocked => _isUnlocked;
  bool get isPinSet => _isPinSet;
  DateTime get selectedDate => _selectedDate;

  String get userName => _userName;
  bool get dailyBriefingEnabled => _dailyBriefingEnabled;
  String get morningBriefingTime => _morningBriefingTime;
  String get eveningBriefingTime => _eveningBriefingTime;
  bool get wakeWordAutoTriggerEnabled => _wakeWordAutoTriggerEnabled;
  bool get autoSpeakBriefing => _autoSpeakBriefing;
  bool get vibrationEnabled => _vibrationEnabled;

  List<CalendarEvent> get events => _events;
  List<RecurrenceRule> get recurrenceRules => _recurrenceRules;
  List<ScheduleException> get exceptions => _exceptions;
  List<TaskItem> get tasks => _tasks;
  List<NoteItem> get notes => _notes;
  List<StudySession> get studySessions => _studySessions;
  List<InboxItem> get inboxItems => _inboxItems;
  List<AlarmItem> get alarms => _alarms;
  List<HabitItem> get habits => _habits;

  List<String> get availableAlarmTones => _customAlarmTones;
  List<String> get availableReminderTones => _customReminderTones;
  String get defaultAlarmTone => _defaultAlarmTone;
  String get defaultReminderTone => _defaultReminderTone;

  String get selectedDateStr =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      final isDark = prefs.getBool('is_dark_mode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }

    _pinHash = prefs.getString('pin_hash');
    _isPinSet = _pinHash != null && _pinHash!.isNotEmpty;
    _isUnlocked = !_isPinSet;

    _defaultAlarmTone = prefs.getString('default_alarm_tone') ?? 'Gentle Chime';
    _defaultReminderTone = prefs.getString('default_reminder_tone') ?? 'Default Chime';

    final savedAlarmTones = prefs.getStringList('custom_alarm_tones');
    if (savedAlarmTones != null && savedAlarmTones.isNotEmpty) {
      _customAlarmTones = savedAlarmTones;
    }

    final savedReminderTones = prefs.getStringList('custom_reminder_tones');
    if (savedReminderTones != null && savedReminderTones.isNotEmpty) {
      _customReminderTones = savedReminderTones;
    }

    // Load tone file path mappings
    final tonePathsJson = prefs.getString('tone_file_paths');
    if (tonePathsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(tonePathsJson);
        decoded.forEach((key, value) {
          _toneFilePaths[key] = value as String?;
        });
      } catch (_) {}
    }

    // Load user & briefing settings
    _userName = prefs.getString('user_name') ?? 'Likhith';
    _dailyBriefingEnabled = prefs.getBool('daily_briefing_enabled') ?? true;
    _morningBriefingTime = prefs.getString('morning_briefing_time') ?? '08:00';
    _eveningBriefingTime = prefs.getString('evening_briefing_time') ?? '21:00';
    _wakeWordAutoTriggerEnabled = prefs.getBool('wake_word_auto_trigger') ?? false;
    _autoSpeakBriefing = prefs.getBool('auto_speak_briefing') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

    await NotificationService.instance.init();
    await WidgetUpdateService.instance.init();
    await refreshData();

    // Warmup non-blocking background services asynchronously
    _warmupBackgroundServices();
  }

  void _warmupBackgroundServices() async {
    try {
      await NotificationService.instance.syncAllAlarms(_alarms, enableVibration: _vibrationEnabled);
      await syncDailyBriefingSchedule();
      AlarmService.instance.startMonitoring(() => _alarms);
      await PermissionService.instance.requestAllAppPermissions();
      await SpeechService.instance.init();
      if (_wakeWordAutoTriggerEnabled) {
        SpeechService.instance.startWakeWordMonitoring(
          onQuery: (query) async {
            final result = await LocalQueryEngine.processQuery(query, this);
            if (result.spokenText.isNotEmpty) {
              await TtsService.instance.speak(result.spokenText);
            }
          },
          onStop: () async {
            await TtsService.instance.stop();
          },
        );
      }
    } catch (_) {}
  }

  // --- HELPER GETTERS FOR TODAY'S WORK & TASKS ---
  String get todayRealDateStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<TaskItem> get todayTasks {
    return _tasks.where((t) {
      if (t.dueDate == selectedDateStr || t.dueDate == null) return true;
      if (selectedDateStr == todayRealDateStr && t.status != 'completed' && t.dueDate != null && t.dueDate!.compareTo(todayRealDateStr) < 0) {
        return true;
      }
      return false;
    }).toList();
  }

  List<TaskItem> get pendingTodayTasks {
    return _tasks.where((t) {
      if ((t.dueDate == selectedDateStr || t.dueDate == null) && t.status != 'completed') return true;
      if (selectedDateStr == todayRealDateStr && t.status != 'completed' && t.dueDate != null && t.dueDate!.compareTo(todayRealDateStr) < 0) {
        return true;
      }
      return false;
    }).toList();
  }

  List<TaskItem> get pendingAllTasks {
    return _tasks.where((t) => t.status != 'completed').toList();
  }

  List<TaskItem> get completedTodayTasks {
    return _tasks.where((t) => (t.dueDate == selectedDateStr || t.dueDate == null) && t.status == 'completed').toList();
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _events.where((e) => e.date == dateStr).toList();
  }

  bool hasEventsOnDay(DateTime day) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return _events.any((e) => e.date == dateStr);
  }

  /// Automatically reschedules uncompleted tasks from past dates to today
  Future<int> autoRescheduleOverdueTasks() async {
    final db = DatabaseHelper.instance;
    final todayReal = todayRealDateStr;
    int rescheduledCount = 0;

    for (final task in _tasks) {
      if (task.status != 'completed' && task.dueDate != null && task.dueDate!.isNotEmpty) {
        if (task.dueDate!.compareTo(todayReal) < 0) {
          final original = task.originalDueDate ?? task.dueDate;
          final updated = task.copyWith(
            dueDate: todayReal,
            isAutoRescheduled: true,
            originalDueDate: original,
          );
          await db.insertTask(updated);
          rescheduledCount++;
        }
      }
    }

    if (rescheduledCount > 0) {
      _tasks = await db.getTasks();
    }
    return rescheduledCount;
  }

  Future<void> refreshData() async {
    final db = DatabaseHelper.instance;
    _events = await db.getEvents();
    _recurrenceRules = await db.getRecurrenceRules();
    _exceptions = await db.getExceptions();
    _tasks = await db.getTasks();
    _notes = await db.getNotes();
    _studySessions = await db.getStudySessions();
    _inboxItems = await db.getInboxItems();
    _alarms = await db.getAlarms();
    _habits = await db.getHabits();

    // Auto-reschedule any overdue uncompleted tasks to today
    await autoRescheduleOverdueTasks();

    // Schedule notifications for all upcoming calendar events
    for (final event in _events) {
      await NotificationService.instance.scheduleEventReminder(event, enableVibration: _vibrationEnabled);
    }

    // Sync Android Home Widget data with today's live stats
    await WidgetUpdateService.instance.updateTodoWidget(
      tasks: _tasks,
      events: _events,
      recurrenceRules: _recurrenceRules,
      exceptions: _exceptions,
    );

    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      await prefs.setString('theme_mode', 'light');
    } else if (mode == ThemeMode.dark) {
      await prefs.setString('theme_mode', 'dark');
    } else {
      await prefs.setString('theme_mode', 'system');
    }
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  // --- PIN LOCK ---
  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _pinHash = _hashPin(pin);
    await prefs.setString('pin_hash', _pinHash!);
    _isPinSet = true;
    _isUnlocked = true;
    notifyListeners();
  }

  bool unlockWithPin(String pin) {
    if (_pinHash != null && _hashPin(pin) == _pinHash) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool verifyPin(String pin) => unlockWithPin(pin);

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pin_hash');
    _pinHash = null;
    _isPinSet = false;
    _isUnlocked = true;
    notifyListeners();
  }

  void lockApp() {
    if (_isPinSet) {
      _isUnlocked = false;
      notifyListeners();
    }
  }

  WeeklyReviewReport getWeeklyReport() {
    return WeeklyReviewEngine.generateReport(
      studySessions: _studySessions,
      tasks: _tasks,
      exceptions: _exceptions,
    );
  }

  List<CandidateSlot> getPostponeCandidates(DateTime fromDate, int durationMinutes) {
    return SchedulingEngine.findCandidateSlots(
      fromDate: fromDate,
      durationMinutes: durationMinutes,
      oneOffEvents: _events,
      recurrenceRules: _recurrenceRules,
      exceptions: _exceptions,
    );
  }

  // --- SCHEDULE RESOLUTION & RESCHEDULING ENGINE ---
  List<ScheduledSlot> getResolvedSchedule(String dateStr) {
    return SchedulingEngine.resolveScheduleForDate(
      targetDate: dateStr,
      oneOffEvents: _events,
      recurrenceRules: _recurrenceRules,
      exceptions: _exceptions,
    );
  }

  Future<void> rescheduleItemUniversal({
    required String itemId,
    required String itemType, // 'event', 'routine', 'task', 'note', 'alarm'
    required String newDate,
    String? newStartTime,
    String? newEndTime,
    bool isExceptionOnly = true,
  }) async {
    if (itemType == 'task') {
      final taskIdx = _tasks.indexWhere((t) => t.id == itemId);
      if (taskIdx != -1) {
        final updated = _tasks[taskIdx].copyWith(dueDate: newDate);
        await DatabaseHelper.instance.insertTask(updated);
      }
    } else if (itemType == 'alarm') {
      final alarmIdx = _alarms.indexWhere((a) => a.id == itemId);
      if (alarmIdx != -1 && newStartTime != null) {
        final updated = _alarms[alarmIdx].copyWith(time: newStartTime);
        await DatabaseHelper.instance.insertAlarm(updated);
        await NotificationService.instance.scheduleAlarmNotification(updated, enableVibration: _vibrationEnabled);
      }
    } else if (itemType == 'event') {
      final eventIdx = _events.indexWhere((e) => e.id == itemId);
      if (eventIdx != -1) {
        final event = _events[eventIdx];
        final updated = event.copyWith(
          date: newDate,
          startTime: newStartTime ?? event.startTime,
          endTime: newEndTime ?? event.endTime,
        );
        await DatabaseHelper.instance.insertEvent(updated);
      }
    } else if (itemType == 'routine') {
      if (isExceptionOnly) {
        final exception = ScheduleException(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          recurrenceRuleId: itemId,
          originalDate: selectedDateStr,
          newDate: newDate,
          newStartTime: newStartTime ?? '',
          newEndTime: newEndTime ?? '',
          reason: 'Universal Reschedule',
        );
        await DatabaseHelper.instance.insertException(exception);
      } else {
        final ruleIdx = _recurrenceRules.indexWhere((r) => r.id == itemId);
        if (ruleIdx != -1 && newStartTime != null && newEndTime != null) {
          final updated = _recurrenceRules[ruleIdx].copyWith(
            startTime: newStartTime,
            endTime: newEndTime,
          );
          await DatabaseHelper.instance.insertRecurrenceRule(updated);
        }
      }
    } else if (itemType == 'note') {
      final noteIdx = _notes.indexWhere((n) => n.id == itemId);
      if (noteIdx != -1) {
        final updated = _notes[noteIdx].copyWith(
          date: newDate,
          startTime: newStartTime ?? _notes[noteIdx].startTime,
        );
        await DatabaseHelper.instance.insertNote(updated);
      }
    }

    await refreshData();
  }

  // --- EVENTS ---
  Future<void> addEvent(CalendarEvent event) async {
    await DatabaseHelper.instance.insertEvent(event);
    await NotificationService.instance.scheduleEventReminder(event, enableVibration: _vibrationEnabled);
    await refreshData();
  }

  Future<void> deleteEvent(String id) async {
    await DatabaseHelper.instance.deleteEvent(id);
    await NotificationService.instance.cancelEventReminder(id);
    await refreshData();
  }

  // --- RECURRING RULES ---
  Future<void> addRecurrenceRule(RecurrenceRule rule) async {
    await DatabaseHelper.instance.insertRecurrenceRule(rule);
    await refreshData();
  }

  // --- TASKS ---
  Future<void> addTask(TaskItem task) async {
    await DatabaseHelper.instance.insertTask(task);
    await refreshData();
  }

  Future<void> toggleTaskStatus(TaskItem task) async {
    final newStatus = task.status == 'completed' ? 'todo' : 'completed';
    final updated = task.copyWith(status: newStatus);
    await DatabaseHelper.instance.insertTask(updated);
    await refreshData();
  }

  Future<void> deleteTask(String id) async {
    await DatabaseHelper.instance.deleteTask(id);
    await refreshData();
  }

  // --- NOTES ---
  Future<void> addNote(NoteItem note) async {
    await DatabaseHelper.instance.insertNote(note);
    await refreshData();
  }

  Future<void> updateNote(NoteItem note) async {
    await DatabaseHelper.instance.insertNote(note);
    await refreshData();
  }

  Future<void> deleteNote(String id) async {
    await DatabaseHelper.instance.deleteNote(id);
    await refreshData();
  }

  Future<void> updateNoteTitle(String id, String title) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final updated = _notes[idx].copyWith(title: title);
      await DatabaseHelper.instance.insertNote(updated);
      await refreshData();
    }
  }

  Future<void> rescheduleNote(String noteId, String newDate, {String? newTime}) async {
    final idx = _notes.indexWhere((n) => n.id == noteId);
    if (idx != -1) {
      final updated = _notes[idx].copyWith(
        date: newDate,
        startTime: newTime ?? _notes[idx].startTime,
      );
      await DatabaseHelper.instance.insertNote(updated);
      await refreshData();
    }
  }

  Future<void> rescheduleTask(String taskId, String newDate, String? newTime) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final updated = _tasks[idx].copyWith(dueDate: newDate);
      await DatabaseHelper.instance.insertTask(updated);
      await refreshData();
    }
  }

  Future<void> rescheduleAlarm(String alarmId, String newTime) async {
    final idx = _alarms.indexWhere((a) => a.id == alarmId);
    if (idx != -1) {
      final updated = _alarms[idx].copyWith(time: newTime);
      await DatabaseHelper.instance.insertAlarm(updated);
      await NotificationService.instance.scheduleAlarmNotification(updated, enableVibration: _vibrationEnabled);
      await refreshData();
    }
  }

  Future<void> rescheduleEvent(String eventId, String newDate, String newStartTime, String newEndTime) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx != -1) {
      final updated = _events[idx].copyWith(
        date: newDate,
        startTime: newStartTime,
        endTime: newEndTime,
      );
      await DatabaseHelper.instance.insertEvent(updated);
      await refreshData();
    }
  }

  Future<void> postponeEvent({
    required String recurrenceRuleId,
    required String originalDate,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    String? reason,
  }) async {
    final exception = ScheduleException(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recurrenceRuleId: recurrenceRuleId,
      originalDate: originalDate,
      newDate: newDate,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      reason: reason,
    );
    await DatabaseHelper.instance.insertException(exception);
    await refreshData();
  }

  // --- STUDY SESSIONS ---
  Future<void> saveStudySession(StudySession session) async {
    await DatabaseHelper.instance.insertStudySession(session);
    await refreshData();
  }

  // --- TONE MANAGEMENT ---
  Future<void> addCustomAlarmTone(String toneName, {String? filePath}) async {
    final trimmed = toneName.trim();
    if (trimmed.isNotEmpty && !_customAlarmTones.contains(trimmed)) {
      _customAlarmTones.add(trimmed);
      if (filePath != null && filePath.isNotEmpty) {
        _toneFilePaths[trimmed] = filePath;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_alarm_tones', _customAlarmTones);
      await _saveToneFilePaths(prefs);
      notifyListeners();
    }
  }

  Future<void> removeCustomAlarmTone(String toneName) async {
    _customAlarmTones.remove(toneName);
    _toneFilePaths.remove(toneName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_alarm_tones', _customAlarmTones);
    await _saveToneFilePaths(prefs);
    notifyListeners();
  }

  Future<void> addCustomReminderTone(String toneName, {String? filePath}) async {
    final trimmed = toneName.trim();
    if (trimmed.isNotEmpty && !_customReminderTones.contains(trimmed)) {
      _customReminderTones.add(trimmed);
      if (filePath != null && filePath.isNotEmpty) {
        _toneFilePaths[trimmed] = filePath;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('custom_reminder_tones', _customReminderTones);
      await _saveToneFilePaths(prefs);
      notifyListeners();
    }
  }

  Future<void> _saveToneFilePaths(SharedPreferences prefs) async {
    await prefs.setString('tone_file_paths', jsonEncode(_toneFilePaths));
  }

  /// Get the file path for a tone name (null if system/preset tone)
  String? getToneFilePath(String toneName) {
    return _toneFilePaths[toneName];
  }

  Future<void> setDefaultAlarmTone(String toneName) async {
    _defaultAlarmTone = toneName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_alarm_tone', toneName);
    notifyListeners();
  }

  Future<void> setDefaultReminderTone(String toneName) async {
    _defaultReminderTone = toneName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_reminder_tone', toneName);
    notifyListeners();
  }

  void previewPlayTone(String toneName) {
    final filePath = getToneFilePath(toneName);
    AlarmSoundService.instance.playPreview(filePath: filePath, toneName: toneName);
  }

  // --- ALARMS ---
  Future<void> addAlarm(AlarmItem alarm) async {
    await DatabaseHelper.instance.insertAlarm(alarm);
    await NotificationService.instance.scheduleAlarmNotification(alarm, enableVibration: _vibrationEnabled);
    await refreshData();
  }

  Future<void> toggleAlarmStatus(AlarmItem alarm) async {
    final updated = alarm.copyWith(isEnabled: !alarm.isEnabled);
    await DatabaseHelper.instance.insertAlarm(updated);
    if (updated.isEnabled) {
      await NotificationService.instance.scheduleAlarmNotification(updated, enableVibration: _vibrationEnabled);
    } else {
      await NotificationService.instance.cancelAlarmNotification(updated.id);
    }
    await refreshData();
  }

  Future<void> deleteAlarm(String id) async {
    await DatabaseHelper.instance.deleteAlarm(id);
    await NotificationService.instance.cancelAlarmNotification(id);
    await refreshData();
  }

  Future<void> snoozeAlarm(AlarmItem alarm, {int snoozeMinutes = 5}) async {
    final now = DateTime.now().add(Duration(minutes: snoozeMinutes));
    final newTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final updated = alarm.copyWith(
      time: newTime,
      isSnoozed: true,
      isEnabled: true,
    );
    await DatabaseHelper.instance.insertAlarm(updated);
    await NotificationService.instance.scheduleAlarmNotification(updated, enableVibration: _vibrationEnabled);
    await refreshData();
  }

  Future<void> dismissAlarm(AlarmItem alarm) async {
    final updated = alarm.copyWith(isSnoozed: false);
    await DatabaseHelper.instance.insertAlarm(updated);
    // If repeat days are set, calculate and schedule next cycle
    if (alarm.repeatDays.isNotEmpty) {
      await NotificationService.instance.scheduleAlarmNotification(updated, enableVibration: _vibrationEnabled);
    } else {
      // One-time alarm can be toggled off
      final disabled = updated.copyWith(isEnabled: false);
      await DatabaseHelper.instance.insertAlarm(disabled);
      await NotificationService.instance.cancelAlarmNotification(disabled.id);
    }
    await refreshData();
  }

  void testAlarmRing(AlarmItem alarm) {
    AlarmService.instance.triggerAlarm(alarm);
  }

  // --- HABITS ---
  Future<void> addHabit(HabitItem habit) async {
    await DatabaseHelper.instance.insertHabit(habit);
    await refreshData();
  }

  Future<void> toggleHabitCompletion(HabitItem habit) async {
    final todayStr = selectedDateStr;
    final isAlreadyCompleted = habit.lastCompletedDate == todayStr;

    final newStreak = isAlreadyCompleted ? (habit.streak > 0 ? habit.streak - 1 : 0) : habit.streak + 1;
    final newLastCompleted = isAlreadyCompleted ? null : todayStr;

    final updated = habit.copyWith(
      streak: newStreak,
      lastCompletedDate: newLastCompleted,
    );
    await DatabaseHelper.instance.insertHabit(updated);
    await refreshData();
  }

  Future<void> deleteHabit(String id) async {
    await DatabaseHelper.instance.deleteHabit(id);
    await refreshData();
  }

  // --- INBOX & NLP QUICK CAPTURE ---
  Future<void> processQuickCapture(String input) async {
    final parsed = NlpParserEngine.parseText(input);

    if (parsed.type == 'alarm') {
      final alarm = AlarmItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed.title,
        time: parsed.startTime ?? '07:00',
        description: parsed.description ?? (parsed.title != 'Wake Up Alarm' ? 'Alarm for ${parsed.title}' : ''),
        isEnabled: true,
        soundRingtone: defaultAlarmTone,
      );
      await addAlarm(alarm);
    } else if (parsed.type == 'habit') {
      final habit = HabitItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed.title,
        description: parsed.description,
        category: parsed.category,
      );
      await addHabit(habit);
    } else if (parsed.type == 'event' && parsed.startTime != null && parsed.endTime != null) {
      final event = CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed.title,
        date: parsed.date ?? selectedDateStr,
        startTime: parsed.startTime!,
        endTime: parsed.endTime!,
        category: parsed.category,
        priority: parsed.priority,
      );
      await addEvent(event);
    } else if (parsed.type == 'note') {
      final note = NoteItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        body: parsed.title,
        category: parsed.category,
        date: parsed.date,
      );
      await addNote(note);
    } else {
      final task = TaskItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed.title,
        dueDate: parsed.date,
        priority: parsed.priority,
      );
      await addTask(task);
    }

    final inbox = InboxItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: input,
      createdAt: DateTime.now().toIso8601String(),
    );
    await DatabaseHelper.instance.insertInboxItem(inbox);
    await refreshData();
  }

  // --- CHECKLISTS ---
  Future<List<ChecklistItem>> getChecklist(String parentId) async {
    final list = await DatabaseHelper.instance.getChecklistItems(parentId);
    _checklists[parentId] = list;
    return list;
  }

  Future<void> addChecklistItem(ChecklistItem item) async {
    await DatabaseHelper.instance.insertChecklistItem(item);
    await getChecklist(item.parentId);
    notifyListeners();
  }

  Future<void> toggleChecklistItem(ChecklistItem item) async {
    final updated = item.copyWith(isDone: !item.isDone);
    await DatabaseHelper.instance.insertChecklistItem(updated);
    await getChecklist(item.parentId);
    notifyListeners();
  }

  // --- DAILY BRIEFING & VOICE WAKE SETTINGS ---
  Future<void> setUserName(String name) async {
    _userName = name.trim().isEmpty ? 'Likhith' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
    await syncDailyBriefingSchedule();
    notifyListeners();
  }

  Future<void> setDailyBriefingEnabled(bool enabled) async {
    _dailyBriefingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_briefing_enabled', enabled);
    await syncDailyBriefingSchedule();
    notifyListeners();
  }

  Future<void> setMorningBriefingTime(String time) async {
    _morningBriefingTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('morning_briefing_time', time);
    await syncDailyBriefingSchedule();
    notifyListeners();
  }

  Future<void> setEveningBriefingTime(String time) async {
    _eveningBriefingTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('evening_briefing_time', time);
    await syncDailyBriefingSchedule();
    notifyListeners();
  }

  Future<void> setWakeWordAutoTriggerEnabled(bool enabled) async {
    _wakeWordAutoTriggerEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wake_word_auto_trigger', enabled);
    if (enabled) {
      SpeechService.instance.startWakeWordMonitoring(
        onQuery: (query) async {
          final result = await LocalQueryEngine.processQuery(query, this);
          if (result.spokenText.isNotEmpty) {
            await TtsService.instance.speak(result.spokenText);
          }
        },
        onStop: () async {
          await TtsService.instance.stop();
        },
      );
    } else {
      SpeechService.instance.stop();
    }
    notifyListeners();
  }

  Future<void> setAutoSpeakBriefing(bool enabled) async {
    _autoSpeakBriefing = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_speak_briefing', enabled);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', enabled);
    await NotificationService.instance.syncAllAlarms(_alarms, enableVibration: enabled);
    await syncDailyBriefingSchedule();
    notifyListeners();
  }

  Future<void> syncDailyBriefingSchedule() async {
    await NotificationService.instance.scheduleDailyBriefings(
      enabled: _dailyBriefingEnabled,
      morningTime: _morningBriefingTime,
      eveningTime: _eveningBriefingTime,
      userName: _userName,
      pendingTasksCount: pendingTodayTasks.length,
      todayEventsCount: getResolvedSchedule(selectedDateStr).length,
      enableVibration: _vibrationEnabled,
    );
  }

  String generateDailyBriefingSpeech({bool isEvening = false}) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final slots = getResolvedSchedule(todayStr);
    final pending = pendingTodayTasks;
    final completed = completedTodayTasks;

    if (isEvening) {
      if (pending.isEmpty) {
        return 'Good evening $_userName! Amazing job today! You have completed all ${completed.length} tasks for today.';
      } else {
        final taskTitles = pending.take(3).map((t) => t.title).join(', and ');
        return 'Good evening $_userName! You completed ${completed.length} tasks today, and have ${pending.length} remaining: $taskTitles.';
      }
    } else {
      if (pending.isEmpty && slots.isEmpty) {
        return 'Good morning $_userName! You currently have no pending tasks or events scheduled for today. Have a relaxed day!';
      }

      List<String> parts = ['Good morning $_userName!'];
      if (pending.isNotEmpty) {
        final taskCountStr = '${pending.length} ${pending.length == 1 ? 'task' : 'tasks'}';
        final top3 = pending.take(3).map((t) => t.title).join(', and ');
        parts.add('You have $taskCountStr on your to-do list: $top3.');
      }
      if (slots.isNotEmpty) {
        final slotTitles = slots.take(3).map((s) => '${s.title} at ${s.startTime}').join(', and ');
        parts.add('Scheduled events include $slotTitles.');
      }
      parts.add('Let\'s have a productive day!');
      return parts.join(' ');
    }
  }
}
