import 'dart:convert';

class CalendarEvent {
  final String id;
  final String title;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String category;
  final int priority; // 1 (low) to 3 (high)
  final String? notes;
  final String completionStatus; // 'pending', 'completed', 'cancelled'
  final String? colorHex; // e.g. '#6366F1'
  final int reminderMinutesBefore; // e.g. 15, 30, 60, 1440 (1 day), 0 (at time), -1 (no reminder)

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.category = 'General',
    this.priority = 2,
    this.notes,
    this.completionStatus = 'pending',
    this.colorHex,
    this.reminderMinutesBefore = 15,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'category': category,
      'priority': priority,
      'notes': notes,
      'completion_status': completionStatus,
      'color_hex': colorHex,
      'reminder_minutes_before': reminderMinutesBefore,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      date: map['date'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      category: map['category'] as String? ?? 'General',
      priority: map['priority'] as int? ?? 2,
      notes: map['notes'] as String?,
      completionStatus: map['completion_status'] as String? ?? 'pending',
      colorHex: map['color_hex'] as String?,
      reminderMinutesBefore: map['reminder_minutes_before'] as int? ?? 15,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? date,
    String? startTime,
    String? endTime,
    String? category,
    int? priority,
    String? notes,
    String? completionStatus,
    String? colorHex,
    int? reminderMinutesBefore,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      completionStatus: completionStatus ?? this.completionStatus,
      colorHex: colorHex ?? this.colorHex,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}

class RecurrenceRule {
  final String id;
  final String title;
  final String daysOfWeek; // e.g. 'MON,WED,FRI' or '1,3,5'
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String category;

  RecurrenceRule({
    required this.id,
    required this.title,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    this.category = 'Routine',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'days_of_week': daysOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'category': category,
    };
  }

  RecurrenceRule copyWith({
    String? id,
    String? title,
    String? daysOfWeek,
    String? startTime,
    String? endTime,
    String? category,
  }) {
    return RecurrenceRule(
      id: id ?? this.id,
      title: title ?? this.title,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
    );
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      id: map['id'] as String,
      title: map['title'] as String,
      daysOfWeek: map['days_of_week'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      category: map['category'] as String? ?? 'Routine',
    );
  }
}

class ScheduleException {
  final String id;
  final String recurrenceRuleId;
  final String originalDate; // YYYY-MM-DD
  final String newDate; // YYYY-MM-DD
  final String newStartTime; // HH:mm
  final String newEndTime; // HH:mm
  final String? reason;

  ScheduleException({
    required this.id,
    required this.recurrenceRuleId,
    required this.originalDate,
    required this.newDate,
    required this.newStartTime,
    required this.newEndTime,
    this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurrence_rule_id': recurrenceRuleId,
      'original_date': originalDate,
      'new_date': newDate,
      'new_start_time': newStartTime,
      'new_end_time': newEndTime,
      'reason': reason,
    };
  }

  factory ScheduleException.fromMap(Map<String, dynamic> map) {
    return ScheduleException(
      id: map['id'] as String,
      recurrenceRuleId: map['recurrence_rule_id'] as String,
      originalDate: map['original_date'] as String,
      newDate: map['new_date'] as String,
      newStartTime: map['new_start_time'] as String,
      newEndTime: map['new_end_time'] as String,
      reason: map['reason'] as String?,
    );
  }
}

class TaskItem {
  final String id;
  final String title;
  final String? dueDate; // YYYY-MM-DD
  final int priority;
  final String status; // 'todo', 'in_progress', 'completed'
  final String? notes;
  final bool isAutoRescheduled;
  final String? originalDueDate;

  TaskItem({
    required this.id,
    required this.title,
    this.dueDate,
    this.priority = 2,
    this.status = 'todo',
    this.notes,
    this.isAutoRescheduled = false,
    this.originalDueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'due_date': dueDate,
      'priority': priority,
      'status': status,
      'notes': notes,
      'is_auto_rescheduled': isAutoRescheduled ? 1 : 0,
      'original_due_date': originalDueDate,
    };
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      dueDate: map['due_date'] as String?,
      priority: map['priority'] as int? ?? 2,
      status: map['status'] as String? ?? 'todo',
      notes: map['notes'] as String?,
      isAutoRescheduled: (map['is_auto_rescheduled'] as int? ?? 0) == 1,
      originalDueDate: map['original_due_date'] as String?,
    );
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? dueDate,
    int? priority,
    String? status,
    String? notes,
    bool? isAutoRescheduled,
    String? originalDueDate,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isAutoRescheduled: isAutoRescheduled ?? this.isAutoRescheduled,
      originalDueDate: originalDueDate ?? this.originalDueDate,
    );
  }
}

class ReminderItem {
  final String id;
  final String linkedItemId;
  final String linkedItemType; // 'event', 'task', 'note'
  final String remindAt; // ISO8601 string

  ReminderItem({
    required this.id,
    required this.linkedItemId,
    required this.linkedItemType,
    required this.remindAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'linked_item_id': linkedItemId,
      'linked_item_type': linkedItemType,
      'remind_at': remindAt,
    };
  }

  factory ReminderItem.fromMap(Map<String, dynamic> map) {
    return ReminderItem(
      id: map['id'] as String,
      linkedItemId: map['linked_item_id'] as String,
      linkedItemType: map['linked_item_type'] as String,
      remindAt: map['remind_at'] as String,
    );
  }
}

class NoteItem {
  final String id;
  final String? title;
  final String body;
  final String? category;
  final String? linkedItemId;
  final String? linkedItemType;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String? reminderAt;

  NoteItem({
    required this.id,
    this.title,
    required this.body,
    this.category,
    this.linkedItemId,
    this.linkedItemType,
    this.date,
    this.startTime,
    this.endTime,
    this.reminderAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'linked_item_id': linkedItemId,
      'linked_item_type': linkedItemType,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'reminder_at': reminderAt,
    };
  }

  factory NoteItem.fromMap(Map<String, dynamic> map) {
    return NoteItem(
      id: map['id'] as String,
      title: map['title'] as String?,
      body: map['body'] as String? ?? '',
      category: map['category'] as String?,
      linkedItemId: map['linked_item_id'] as String?,
      linkedItemType: map['linked_item_type'] as String?,
      date: map['date'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      reminderAt: map['reminder_at'] as String?,
    );
  }

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) {
      return title!.trim();
    }
    return 'Untitled';
  }

  bool get isUntitled =>
      title == null || title!.trim().isEmpty || title!.trim().toLowerCase() == 'untitled';

  NoteItem copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? linkedItemId,
    String? linkedItemType,
    String? date,
    String? startTime,
    String? endTime,
    String? reminderAt,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      linkedItemId: linkedItemId ?? this.linkedItemId,
      linkedItemType: linkedItemType ?? this.linkedItemType,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reminderAt: reminderAt ?? this.reminderAt,
    );
  }
}

class StudySession {
  final String id;
  final String subject;
  final int plannedMinutes;
  final int actualMinutes;
  final String startTs;
  final String endTs;
  final int pausedMs;
  final String? notes;

  StudySession({
    required this.id,
    required this.subject,
    required this.plannedMinutes,
    required this.actualMinutes,
    required this.startTs,
    required this.endTs,
    this.pausedMs = 0,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'planned_minutes': plannedMinutes,
      'actual_minutes': actualMinutes,
      'start_ts': startTs,
      'end_ts': endTs,
      'paused_ms': pausedMs,
      'notes': notes,
    };
  }

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as String,
      subject: map['subject'] as String,
      plannedMinutes: map['planned_minutes'] as int? ?? 0,
      actualMinutes: map['actual_minutes'] as int? ?? 0,
      startTs: map['start_ts'] as String,
      endTs: map['end_ts'] as String,
      pausedMs: map['paused_ms'] as int? ?? 0,
      notes: map['notes'] as String?,
    );
  }
}

class GoalItem {
  final String id;
  final String title;
  final List<String> subtopics;

  GoalItem({
    required this.id,
    required this.title,
    this.subtopics = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtopics_json': jsonEncode(subtopics),
    };
  }

  factory GoalItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedSubtopics = [];
    if (map['subtopics_json'] != null) {
      try {
        parsedSubtopics = List<String>.from(jsonDecode(map['subtopics_json']));
      } catch (_) {}
    }
    return GoalItem(
      id: map['id'] as String,
      title: map['title'] as String,
      subtopics: parsedSubtopics,
    );
  }
}

class InboxItem {
  final String id;
  final String text;
  final String createdAt;

  InboxItem({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'created_at': createdAt,
    };
  }

  factory InboxItem.fromMap(Map<String, dynamic> map) {
    return InboxItem(
      id: map['id'] as String,
      text: map['text'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

class ChecklistItem {
  final String id;
  final String parentId;
  final String parentType; // 'note', 'task', 'event'
  final String text;
  final bool isDone;
  final int sortOrder;

  ChecklistItem({
    required this.id,
    required this.parentId,
    required this.parentType,
    required this.text,
    this.isDone = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'parent_type': parentType,
      'text': text,
      'is_done': isDone ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      parentType: map['parent_type'] as String,
      text: map['text'] as String,
      isDone: (map['is_done'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? parentId,
    String? parentType,
    String? text,
    bool? isDone,
    int? sortOrder,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      parentType: parentType ?? this.parentType,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class AttachmentItem {
  final String id;
  final String linkedItemId;
  final String linkedItemType;
  final String filePath;
  final String fileType;
  final String createdAt;

  AttachmentItem({
    required this.id,
    required this.linkedItemId,
    required this.linkedItemType,
    required this.filePath,
    required this.fileType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'linked_item_id': linkedItemId,
      'linked_item_type': linkedItemType,
      'file_path': filePath,
      'file_type': fileType,
      'created_at': createdAt,
    };
  }

  factory AttachmentItem.fromMap(Map<String, dynamic> map) {
    return AttachmentItem(
      id: map['id'] as String,
      linkedItemId: map['linked_item_id'] as String,
      linkedItemType: map['linked_item_type'] as String,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

class TagItem {
  final String id;
  final String name;

  TagItem({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory TagItem.fromMap(Map<String, dynamic> map) {
    return TagItem(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}

class PomodoroSettings {
  final String id;
  final String? subject;
  final int workMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;

  PomodoroSettings({
    required this.id,
    this.subject,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'work_minutes': workMinutes,
      'break_minutes': breakMinutes,
      'long_break_minutes': longBreakMinutes,
      'cycles_before_long_break': cyclesBeforeLongBreak,
    };
  }

  factory PomodoroSettings.fromMap(Map<String, dynamic> map) {
    return PomodoroSettings(
      id: map['id'] as String,
      subject: map['subject'] as String?,
      workMinutes: map['work_minutes'] as int? ?? 25,
      breakMinutes: map['break_minutes'] as int? ?? 5,
      longBreakMinutes: map['long_break_minutes'] as int? ?? 15,
      cyclesBeforeLongBreak: map['cycles_before_long_break'] as int? ?? 4,
    );
  }
}

class AlarmItem {
  final String id;
  final String title;
  final String time; // HH:mm format
  final String description; // Custom description displayed when alarm triggers
  final bool isEnabled;
  final List<String> repeatDays; // e.g. ["Mon", "Tue", "Wed"]
  final String soundRingtone;
  final int snoozeDurationMinutes;
  final bool isSnoozed;
  final bool vibrate;

  AlarmItem({
    required this.id,
    required this.title,
    required this.time,
    required this.description,
    this.isEnabled = true,
    this.repeatDays = const [],
    this.soundRingtone = 'Gentle Chime',
    this.snoozeDurationMinutes = 5,
    this.isSnoozed = false,
    this.vibrate = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'time': time,
      'description': description,
      'is_enabled': isEnabled ? 1 : 0,
      'repeat_days_json': jsonEncode(repeatDays),
      'sound_ringtone': soundRingtone,
      'snooze_duration_minutes': snoozeDurationMinutes,
      'is_snoozed': isSnoozed ? 1 : 0,
      'vibrate': vibrate ? 1 : 0,
    };
  }

  factory AlarmItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedRepeatDays = [];
    if (map['repeat_days_json'] != null) {
      try {
        parsedRepeatDays = List<String>.from(jsonDecode(map['repeat_days_json']));
      } catch (_) {}
    }
    return AlarmItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Alarm',
      time: map['time'] as String,
      description: map['description'] as String? ?? '',
      isEnabled: (map['is_enabled'] as int? ?? 1) == 1,
      repeatDays: parsedRepeatDays,
      soundRingtone: map['sound_ringtone'] as String? ?? 'Gentle Chime',
      snoozeDurationMinutes: map['snooze_duration_minutes'] as int? ?? 5,
      isSnoozed: (map['is_snoozed'] as int? ?? 0) == 1,
      vibrate: (map['vibrate'] as int? ?? 1) == 1,
    );
  }

  AlarmItem copyWith({
    String? id,
    String? title,
    String? time,
    String? description,
    bool? isEnabled,
    List<String>? repeatDays,
    String? soundRingtone,
    int? snoozeDurationMinutes,
    bool? isSnoozed,
    bool? vibrate,
  }) {
    return AlarmItem(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      soundRingtone: soundRingtone ?? this.soundRingtone,
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      vibrate: vibrate ?? this.vibrate,
    );
  }
}

class HabitItem {
  final String id;
  final String title;
  final String? description;
  final int streak;
  final String? lastCompletedDate; // YYYY-MM-DD
  final int targetDaysPerWeek;
  final String category;

  HabitItem({
    required this.id,
    required this.title,
    this.description,
    this.streak = 0,
    this.lastCompletedDate,
    this.targetDaysPerWeek = 7,
    this.category = 'Health',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'streak': streak,
      'last_completed_date': lastCompletedDate,
      'target_days_per_week': targetDaysPerWeek,
      'category': category,
    };
  }

  factory HabitItem.fromMap(Map<String, dynamic> map) {
    return HabitItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      streak: map['streak'] as int? ?? 0,
      lastCompletedDate: map['last_completed_date'] as String?,
      targetDaysPerWeek: map['target_days_per_week'] as int? ?? 7,
      category: map['category'] as String? ?? 'Health',
    );
  }

  HabitItem copyWith({
    String? id,
    String? title,
    String? description,
    int? streak,
    String? lastCompletedDate,
    int? targetDaysPerWeek,
    String? category,
  }) {
    return HabitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      streak: streak ?? this.streak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
      category: category ?? this.category,
    );
  }
}

