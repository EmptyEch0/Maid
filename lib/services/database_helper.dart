import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/app_models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('maid.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // In web environment, sqflite_common_ffi or memory db
      databaseFactory = databaseFactoryFfi;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = join(docDir.path, 'MaidData', filePath);
      final dir = Directory(dirname(dbPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final dbDir = await getDatabasesPath();
      dbPath = join(dbDir, filePath);
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        category TEXT NOT NULL,
        priority INTEGER NOT NULL,
        notes TEXT,
        completion_status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recurrence_rules (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        days_of_week TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE exceptions (
        id TEXT PRIMARY KEY,
        recurrence_rule_id TEXT NOT NULL,
        original_date TEXT NOT NULL,
        new_date TEXT NOT NULL,
        new_start_time TEXT NOT NULL,
        new_end_time TEXT NOT NULL,
        reason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        due_date TEXT,
        priority INTEGER NOT NULL,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        linked_item_id TEXT NOT NULL,
        linked_item_type TEXT NOT NULL,
        remind_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT,
        body TEXT NOT NULL,
        category TEXT,
        linked_item_id TEXT,
        linked_item_type TEXT,
        date TEXT,
        start_time TEXT,
        end_time TEXT,
        reminder_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE study_sessions (
        id TEXT PRIMARY KEY,
        subject TEXT NOT NULL,
        planned_minutes INTEGER NOT NULL,
        actual_minutes INTEGER NOT NULL,
        start_ts TEXT NOT NULL,
        end_ts TEXT NOT NULL,
        paused_ms INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtopics_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE inbox (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY,
        parent_id TEXT NOT NULL,
        parent_type TEXT NOT NULL,
        text TEXT NOT NULL,
        is_done INTEGER NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        linked_item_id TEXT NOT NULL,
        linked_item_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE item_tags (
        id TEXT PRIMARY KEY,
        tag_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        item_type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pomodoro_settings (
        id TEXT PRIMARY KEY,
        subject TEXT,
        work_minutes INTEGER NOT NULL,
        break_minutes INTEGER NOT NULL,
        long_break_minutes INTEGER NOT NULL,
        cycles_before_long_break INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_lock (
        id TEXT PRIMARY KEY,
        pin_hash TEXT,
        biometric_enabled INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarms (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        description TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        repeat_days_json TEXT,
        sound_ringtone TEXT NOT NULL,
        snooze_duration_minutes INTEGER NOT NULL,
        is_snoozed INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        streak INTEGER NOT NULL,
        last_completed_date TEXT,
        target_days_per_week INTEGER NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    // Seed default Pomodoro Settings
    await db.insert('pomodoro_settings', {
      'id': 'default',
      'subject': 'General Study',
      'work_minutes': 25,
      'break_minutes': 5,
      'long_break_minutes': 15,
      'cycles_before_long_break': 4,
    });
  }

  Future<void> _ensureTablesCreated(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarms (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        description TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        repeat_days_json TEXT,
        sound_ringtone TEXT NOT NULL,
        snooze_duration_minutes INTEGER NOT NULL,
        is_snoozed INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        streak INTEGER NOT NULL,
        last_completed_date TEXT,
        target_days_per_week INTEGER NOT NULL,
        category TEXT NOT NULL
      )
    ''');
  }

  // --- ALARMS ---
  Future<void> insertAlarm(AlarmItem alarm) async {
    final db = await database;
    await _ensureTablesCreated(db);
    await db.insert('alarms', alarm.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AlarmItem>> getAlarms() async {
    final db = await database;
    await _ensureTablesCreated(db);
    final maps = await db.query('alarms');
    return maps.map((m) => AlarmItem.fromMap(m)).toList();
  }

  Future<void> deleteAlarm(String id) async {
    final db = await database;
    await _ensureTablesCreated(db);
    await db.delete('alarms', where: 'id = ?', whereArgs: [id]);
  }

  // --- HABITS ---
  Future<void> insertHabit(HabitItem habit) async {
    final db = await database;
    await _ensureTablesCreated(db);
    await db.insert('habits', habit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HabitItem>> getHabits() async {
    final db = await database;
    await _ensureTablesCreated(db);
    final maps = await db.query('habits');
    return maps.map((m) => HabitItem.fromMap(m)).toList();
  }

  Future<void> deleteHabit(String id) async {
    final db = await database;
    await _ensureTablesCreated(db);
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // --- EVENTS ---
  Future<void> insertEvent(CalendarEvent event) async {
    final db = await database;
    await db.insert('events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CalendarEvent>> getEvents() async {
    final db = await database;
    final maps = await db.query('events');
    return maps.map((m) => CalendarEvent.fromMap(m)).toList();
  }

  Future<List<CalendarEvent>> getEventsForDate(String date) async {
    final db = await database;
    final maps = await db.query('events', where: 'date = ?', whereArgs: [date]);
    return maps.map((m) => CalendarEvent.fromMap(m)).toList();
  }

  Future<void> deleteEvent(String id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // --- RECURRENCE & EXCEPTIONS ---
  Future<void> insertRecurrenceRule(RecurrenceRule rule) async {
    final db = await database;
    await db.insert('recurrence_rules', rule.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RecurrenceRule>> getRecurrenceRules() async {
    final db = await database;
    final maps = await db.query('recurrence_rules');
    return maps.map((m) => RecurrenceRule.fromMap(m)).toList();
  }

  Future<void> insertException(ScheduleException exc) async {
    final db = await database;
    await db.insert('exceptions', exc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScheduleException>> getExceptions() async {
    final db = await database;
    final maps = await db.query('exceptions');
    return maps.map((m) => ScheduleException.fromMap(m)).toList();
  }

  // --- TASKS ---
  Future<void> insertTask(TaskItem task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TaskItem>> getTasks() async {
    final db = await database;
    final maps = await db.query('tasks');
    return maps.map((m) => TaskItem.fromMap(m)).toList();
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- NOTES ---
  Future<void> insertNote(NoteItem note) async {
    final db = await database;
    await db.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NoteItem>> getNotes() async {
    final db = await database;
    final maps = await db.query('notes');
    return maps.map((m) => NoteItem.fromMap(m)).toList();
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- STUDY SESSIONS ---
  Future<void> insertStudySession(StudySession session) async {
    final db = await database;
    await db.insert('study_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StudySession>> getStudySessions() async {
    final db = await database;
    final maps = await db.query('study_sessions');
    return maps.map((m) => StudySession.fromMap(m)).toList();
  }

  // --- INBOX ---
  Future<void> insertInboxItem(InboxItem item) async {
    final db = await database;
    await db.insert('inbox', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<InboxItem>> getInboxItems() async {
    final db = await database;
    final maps = await db.query('inbox', orderBy: 'created_at DESC');
    return maps.map((m) => InboxItem.fromMap(m)).toList();
  }

  Future<void> deleteInboxItem(String id) async {
    final db = await database;
    await db.delete('inbox', where: 'id = ?', whereArgs: [id]);
  }

  // --- CHECKLIST ITEMS ---
  Future<void> insertChecklistItem(ChecklistItem item) async {
    final db = await database;
    await db.insert('checklist_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChecklistItem>> getChecklistItems(String parentId) async {
    final db = await database;
    final maps = await db.query('checklist_items', where: 'parent_id = ?', whereArgs: [parentId], orderBy: 'sort_order ASC');
    return maps.map((m) => ChecklistItem.fromMap(m)).toList();
  }

  Future<void> deleteChecklistItem(String id) async {
    final db = await database;
    await db.delete('checklist_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- POMODORO SETTINGS ---
  Future<PomodoroSettings> getPomodoroSettings() async {
    final db = await database;
    final maps = await db.query('pomodoro_settings', where: "id = 'default'");
    if (maps.isNotEmpty) {
      return PomodoroSettings.fromMap(maps.first);
    }
    return PomodoroSettings(id: 'default');
  }

  Future<void> savePomodoroSettings(PomodoroSettings settings) async {
    final db = await database;
    await db.insert('pomodoro_settings', settings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- CLEAR / RAW EXPORT ---
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'events': await db.query('events'),
      'recurrence_rules': await db.query('recurrence_rules'),
      'exceptions': await db.query('exceptions'),
      'tasks': await db.query('tasks'),
      'notes': await db.query('notes'),
      'study_sessions': await db.query('study_sessions'),
      'inbox': await db.query('inbox'),
      'checklist_items': await db.query('checklist_items'),
    };
  }
}
