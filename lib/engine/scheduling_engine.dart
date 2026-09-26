import 'package:intl/intl.dart';
import '../models/app_models.dart';

class ScheduledSlot {
  final String id;
  final String title;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String category;
  final bool isRecurringInstance;
  final String? recurrenceRuleId;
  final bool isException;
  final String? originalDate;
  final String? colorHex;
  final int reminderMinutesBefore;

  ScheduledSlot({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.category,
    this.isRecurringInstance = false,
    this.recurrenceRuleId,
    this.isException = false,
    this.originalDate,
    this.colorHex,
    this.reminderMinutesBefore = 15,
  });

  DateTime get startDateTime {
    final parts = startTime.split(':');
    final dtParts = date.split('-');
    return DateTime(
      int.parse(dtParts[0]),
      int.parse(dtParts[1]),
      int.parse(dtParts[2]),
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  DateTime get endDateTime {
    final parts = endTime.split(':');
    final dtParts = date.split('-');
    return DateTime(
      int.parse(dtParts[0]),
      int.parse(dtParts[1]),
      int.parse(dtParts[2]),
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

class CandidateSlot {
  final String date;
  final String startTime;
  final String endTime;

  CandidateSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  String get label => '$date ($startTime - $endTime)';
}

class SchedulingEngine {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Merges standard one-off events, recurring rules, and schedule exceptions for a target date.
  static List<ScheduledSlot> resolveScheduleForDate({
    required String targetDate, // YYYY-MM-DD
    required List<CalendarEvent> oneOffEvents,
    required List<RecurrenceRule> recurrenceRules,
    required List<ScheduleException> exceptions,
  }) {
    final List<ScheduledSlot> resolved = [];

    // 1. One-off events on targetDate
    for (var event in oneOffEvents) {
      if (event.date == targetDate) {
        resolved.add(ScheduledSlot(
          id: event.id,
          title: event.title,
          date: event.date,
          startTime: event.startTime,
          endTime: event.endTime,
          category: event.category,
          isRecurringInstance: false,
          colorHex: event.colorHex,
          reminderMinutesBefore: event.reminderMinutesBefore,
        ));
      }
    }

    final targetDateTime = DateTime.parse(targetDate);
    final dayOfWeekStr = _getDayOfWeekString(targetDateTime.weekday);

    // 2. Recurrence rules
    for (var rule in recurrenceRules) {
      final activeDays = rule.daysOfWeek.toUpperCase().split(',').map((e) => e.trim()).toList();

      if (activeDays.contains(dayOfWeekStr) || activeDays.contains(targetDateTime.weekday.toString())) {
        // Check if there is an exception overriding this recurring slot on targetDate
        final hasOriginalException = exceptions.any((ex) =>
            ex.recurrenceRuleId == rule.id && ex.originalDate == targetDate);

        if (!hasOriginalException) {
          resolved.add(ScheduledSlot(
            id: 'rec_${rule.id}_$targetDate',
            title: rule.title,
            date: targetDate,
            startTime: rule.startTime,
            endTime: rule.endTime,
            category: rule.category,
            isRecurringInstance: true,
            recurrenceRuleId: rule.id,
          ));
        }
      }
    }

    // 3. Postponed exceptions rescheduled TO targetDate
    for (var ex in exceptions) {
      if (ex.newDate == targetDate) {
        final parentRule = recurrenceRules.firstWhere(
          (r) => r.id == ex.recurrenceRuleId,
          orElse: () => RecurrenceRule(
            id: ex.recurrenceRuleId,
            title: 'Postponed Event',
            daysOfWeek: '',
            startTime: ex.newStartTime,
            endTime: ex.newEndTime,
          ),
        );

        resolved.add(ScheduledSlot(
          id: 'exc_${ex.id}',
          title: '${parentRule.title} (Rescheduled)',
          date: targetDate,
          startTime: ex.newStartTime,
          endTime: ex.newEndTime,
          category: parentRule.category,
          isRecurringInstance: true,
          recurrenceRuleId: ex.recurrenceRuleId,
          isException: true,
          originalDate: ex.originalDate,
        ));
      }
    }

    // Sort by startTime
    resolved.sort((a, b) => a.startTime.compareTo(b.startTime));
    return resolved;
  }

  /// Detects conflicts (overlapping time slots) in a list of scheduled slots.
  static List<String> detectConflicts(List<ScheduledSlot> slots) {
    final List<String> conflicts = [];
    for (int i = 0; i < slots.length; i++) {
      for (int j = i + 1; j < slots.length; j++) {
        final a = slots[i];
        final b = slots[j];

        if (_isOverlapping(a.startDateTime, a.endDateTime, b.startDateTime, b.endDateTime)) {
          conflicts.add('Conflict between "${a.title}" (${a.startTime}-${a.endTime}) and "${b.title}" (${b.startTime}-${b.endTime})');
        }
      }
    }
    return conflicts;
  }

  /// Suggests candidate free time slots for postponing an event/task.
  static List<CandidateSlot> findCandidateSlots({
    required DateTime fromDate,
    required int durationMinutes,
    required List<CalendarEvent> oneOffEvents,
    required List<RecurrenceRule> recurrenceRules,
    required List<ScheduleException> exceptions,
    int daysToScan = 3,
  }) {
    final List<CandidateSlot> candidates = [];

    for (int d = 0; d < daysToScan; d++) {
      final scanDate = fromDate.add(Duration(days: d));
      final dateStr = _dateFormat.format(scanDate);
      final existingSlots = resolveScheduleForDate(
        targetDate: dateStr,
        oneOffEvents: oneOffEvents,
        recurrenceRules: recurrenceRules,
        exceptions: exceptions,
      );

      // Scan hours 08:00 to 22:00
      for (int hour = 8; hour <= 20; hour++) {
        final start = DateTime(scanDate.year, scanDate.month, scanDate.day, hour, 0);
        final end = start.add(Duration(minutes: durationMinutes));

        bool conflict = false;
        for (var slot in existingSlots) {
          if (_isOverlapping(start, end, slot.startDateTime, slot.endDateTime)) {
            conflict = true;
            break;
          }
        }

        if (!conflict) {
          final startStr = '${hour.toString().padLeft(2, '0')}:00';
          final endHour = hour + (durationMinutes ~/ 60);
          final endMin = durationMinutes % 60;
          final endStr = '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';

          candidates.add(CandidateSlot(
            date: dateStr,
            startTime: startStr,
            endTime: endStr,
          ));

          if (candidates.length >= 4) return candidates;
        }
      }
    }

    return candidates;
  }

  static bool _isOverlapping(DateTime s1, DateTime e1, DateTime s2, DateTime e2) {
    return s1.isBefore(e2) && e1.isAfter(s2);
  }

  static String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
      default:
        return '';
    }
  }
}
