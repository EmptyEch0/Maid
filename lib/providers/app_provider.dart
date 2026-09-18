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

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get isUnlocked => _isUnlocked;
  bool get isPinSet => _isPinSet;
  DateTime get selectedDate => _selectedDate;

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

    await NotificationService.instance.init();
    await WidgetUpdateService.instance.init();
    await PermissionService.instance.requestAllAppPermissions();
    await SpeechService.instance.init();
    await refreshData();

    // Sync all alarms with exact Android Notification scheduler
    await NotificationService.instance.syncAllAlarms(_alarms);

    AlarmService.instance.startMonitoring(() => _alarms);
  }

  // --- HELPER GETTERS FOR TODAY'S WORK & TASKS ---
  List<TaskItem> get todayTasks {
    return _tasks.where((t) => t.dueDate == selectedDateStr || t.dueDate == null).toList();
  }

  List<TaskItem> get pendingTodayTasks {
    return _tasks.where((t) => (t.dueDate == selectedDateStr || t.dueDate == null) && t.status != 'completed').toList();
  }

  List<TaskItem> get pendingAllTasks {
    return _tasks.where((t) => t.status != 'completed').toList();
  }

  List<TaskItem> get completedTodayTasks {
    return _tasks.where((t) => (t.dueDate == selectedDateStr || t.dueDate == null) && t.status == 'completed').toList();
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
    _syncWidget();
    notifyListeners();
  }

  void _syncWidget() {
    WidgetUpdateService.instance.updateTodoWidget(
      tasks: _tasks,
      events: _events,
      recurrenceRules: _recurrenceRules,
      exceptions: _exceptions,
    );
  }

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    await prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      await prefs.setString('theme_mode', 'light');
      await prefs.setBool('is_dark_mode', false);
    } else if (mode == ThemeMode.dark) {
      await prefs.setString('theme_mode', 'dark');
      await prefs.setBool('is_dark_mode', true);
    } else {
      await prefs.setString('theme_mode', 'system');
    }
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // --- SECURITY LOCK ---
  bool verifyPin(String pin) {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    if (hash == _pinHash) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> setPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    _pinHash = hash;
    _isPinSet = true;
    _isUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_hash', hash);
    notifyListeners();
  }

  Future<void> removePin() async {
    _pinHash = null;
    _isPinSet = false;
    _isUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pin_hash');
    notifyListeners();
  }

  void lockApp() {
    if (_isPinSet) {
      _isUnlocked = false;
      notifyListeners();
    }
  }

  // --- EVENTS & RECURRENCE ---
  Future<void> addEvent(CalendarEvent event) async {
    await DatabaseHelper.instance.insertEvent(event);
    await refreshData();
  }

  Future<void> deleteEvent(String id) async {
    await DatabaseHelper.instance.deleteEvent(id);
    await refreshData();
  }

  Future<void> addRecurrenceRule(RecurrenceRule rule) async {
    await DatabaseHelper.instance.insertRecurrenceRule(rule);
    await refreshData();
  }

  Future<void> postponeEvent({
    required String recurrenceRuleId,
    required String originalDate,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    String? reason,
  }) async {
    final exc = ScheduleException(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recurrenceRuleId: recurrenceRuleId,
      originalDate: originalDate,
      newDate: newDate,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      reason: reason,
    );
    await DatabaseHelper.instance.insertException(exc);
    await refreshData();
  }

  List<ScheduledSlot> getResolvedSchedule(String dateStr) {
    return SchedulingEngine.resolveScheduleForDate(
      targetDate: dateStr,
      oneOffEvents: _events,
      recurrenceRules: _recurrenceRules,
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

  Future<void> deleteNote(String id) async {
    await DatabaseHelper.instance.deleteNote(id);
    await refreshData();
  }

  // --- UNIVERSAL RESCHEDULING METHODS ---
  Future<void> rescheduleEvent(String id, String newDate, String newStartTime, String newEndTime) async {
    final idx = _events.indexWhere((e) => e.id == id);
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

  Future<void> rescheduleTask(String id, String newDueDate, [String? newDueTime]) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = _tasks[idx].copyWith(dueDate: newDueDate);
      await DatabaseHelper.instance.insertTask(updated);
      await refreshData();
    }
  }

  Future<void> rescheduleAlarm(String id, String newTime, [List<String>? newDays]) async {
    final idx = _alarms.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final updated = _alarms[idx].copyWith(
        time: newTime,
        repeatDays: newDays ?? _alarms[idx].repeatDays,
        isEnabled: true,
      );
      await DatabaseHelper.instance.insertAlarm(updated);
      await NotificationService.instance.scheduleAlarmNotification(updated);
      await refreshData();
    }
  }

  Future<void> rescheduleNote(String id, String newDate, [String? newTime]) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final updated = _notes[idx].copyWith(
        date: newDate,
        startTime: newTime ?? _notes[idx].startTime,
      );
      await DatabaseHelper.instance.insertNote(updated);
      await refreshData();
    }
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
    await NotificationService.instance.scheduleAlarmNotification(alarm);
    await refreshData();
  }

  Future<void> toggleAlarmStatus(AlarmItem alarm) async {
    final updated = alarm.copyWith(isEnabled: !alarm.isEnabled);
    await DatabaseHelper.instance.insertAlarm(updated);
    if (updated.isEnabled) {
      await NotificationService.instance.scheduleAlarmNotification(updated);
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

  Future<void> snoozeAlarm(AlarmItem alarm) async {
    final now = DateTime.now().add(Duration(minutes: alarm.snoozeDurationMinutes));
    final formattedHour = now.hour.toString().padLeft(2, '0');
    final formattedMinute = now.minute.toString().padLeft(2, '0');
    final newTime = '$formattedHour:$formattedMinute';

    final updated = alarm.copyWith(
      time: newTime,
      isSnoozed: true,
      isEnabled: true,
    );
    await DatabaseHelper.instance.insertAlarm(updated);
    await NotificationService.instance.scheduleAlarmNotification(updated);
    await refreshData();
  }

  Future<void> dismissAlarm(AlarmItem alarm) async {
    final updated = alarm.copyWith(isSnoozed: false);
    await DatabaseHelper.instance.insertAlarm(updated);
    // If repeat days are set, calculate and schedule next cycle
    if (alarm.repeatDays.isNotEmpty) {
      await NotificationService.instance.scheduleAlarmNotification(updated);
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

  // --- WEEKLY REVIEW ---
  WeeklyReviewReport getWeeklyReport() {
    return WeeklyReviewEngine.generateReport(
      studySessions: _studySessions,
      tasks: _tasks,
      exceptions: _exceptions,
    );
  }
}
